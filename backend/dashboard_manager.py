"""Python peer of src/managers/dashboardmanager.{h,cpp}.

Both backends scan the same on-disk JSON layout:

- Built-in presets: frontend/dashboards/presets/*.json (read-only)
- User dashboards:  <app_data_dir>/dashboards/*.json  (read/write)

The QML frontend binds to a single `dashboardManager` context property whose
public API must stay identical across backends. Keep this file and the C++
header aligned — if you add a Slot here, add the Q_INVOKABLE on the C++ side
in the same change set.
"""

import json
import os
import re
import tempfile
import time

from PySide6.QtCore import QObject, Property, Signal, Slot

from backend.logging_config import get_logger

logger = get_logger(__name__)


class DashboardManager(QObject):
    dashboardsChanged = Signal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self._presets_dir = ""
        self._user_dir = ""
        self._dashboards = []

    # ------------------------------------------------------------------
    # Configuration
    # ------------------------------------------------------------------

    def setPresetsDir(self, absolute_path: str):
        self._presets_dir = absolute_path or ""

    def setUserDir(self, absolute_path: str):
        self._user_dir = absolute_path or ""
        self._rescan_all()

    # ------------------------------------------------------------------
    # QML-visible API
    # ------------------------------------------------------------------

    @Property('QVariantList', notify=dashboardsChanged)
    def dashboards(self):
        return self._dashboards

    @Slot(str, result='QVariant')
    def loadDashboard(self, dashboard_id: str):
        entry = self._find_entry(dashboard_id)
        if not entry:
            logger.warning("loadDashboard: unknown id %s", dashboard_id)
            return {}
        return self._read_full_spec(entry["path"])

    @Slot(str, result=bool)
    def isBuiltIn(self, dashboard_id: str) -> bool:
        return bool(self._find_entry(dashboard_id).get("builtIn", False))

    @Slot('QVariantMap', result=str)
    def saveDashboard(self, spec) -> str:
        spec = dict(spec or {})
        dashboard_id = str(spec.get("id", "") or "")
        label = str(spec.get("label", "") or "")

        if not dashboard_id or not label:
            logger.warning("saveDashboard requires id and label")
            return ""
        if not self._user_dir:
            logger.warning("User dashboards dir not configured")
            return ""

        existing = self._find_entry(dashboard_id)
        if existing and existing.get("builtIn"):
            logger.warning(
                "Cannot save: id %s collides with a built-in preset",
                dashboard_id,
            )
            return ""

        path = os.path.join(self._user_dir, dashboard_id + ".json")
        if not self._write_spec(path, spec):
            return ""

        self._rescan_all()
        return dashboard_id

    @Slot(str, result=bool)
    def deleteDashboard(self, dashboard_id: str) -> bool:
        entry = self._find_entry(dashboard_id)
        if not entry:
            return False
        if entry.get("builtIn"):
            logger.warning("Refusing to delete built-in dashboard: %s", dashboard_id)
            return False
        try:
            os.remove(entry["path"])
        except OSError as e:
            logger.warning("Failed to delete %s: %s", entry["path"], e)
            return False
        self._rescan_all()
        return True

    @Slot(str, str, result=str)
    def duplicateDashboard(self, source_id: str, new_label: str) -> str:
        entry = self._find_entry(source_id)
        if not entry:
            logger.warning("duplicateDashboard: unknown source id %s", source_id)
            return ""

        spec = self._read_full_spec(entry["path"])
        if not spec:
            return ""

        final_label = new_label if new_label else f"{entry.get('label', '')} (Copy)"
        new_id = self._unique_user_id_from_label(final_label)

        spec["id"] = new_id
        spec["label"] = final_label

        return self.saveDashboard(spec)

    @Slot()
    def refresh(self):
        self._rescan_all()

    # ------------------------------------------------------------------
    # Internals
    # ------------------------------------------------------------------

    def _find_entry(self, dashboard_id: str) -> dict:
        for entry in self._dashboards:
            if entry.get("id") == dashboard_id:
                return entry
        return {}

    def _existing_ids(self) -> set:
        return {entry.get("id", "") for entry in self._dashboards}

    def _ensure_user_dir(self):
        if self._user_dir:
            os.makedirs(self._user_dir, exist_ok=True)

    def _rescan_all(self):
        self._dashboards = []
        taken_ids = set()

        # Built-ins first. Any user JSON that tries to reuse a built-in id
        # gets rejected below (same rule the C++ side enforces).
        if self._presets_dir:
            if os.path.isdir(self._presets_dir):
                for fname in sorted(os.listdir(self._presets_dir)):
                    if not fname.endswith(".json"):
                        continue
                    path = os.path.join(self._presets_dir, fname)
                    header = self._read_header(path)
                    if not header:
                        continue
                    dashboard_id = header.get("id", "")
                    if not dashboard_id or dashboard_id in taken_ids:
                        logger.warning(
                            "Skipping preset with missing or duplicate id: %s",
                            fname,
                        )
                        continue
                    self._dashboards.append({
                        "id": dashboard_id,
                        "label": header.get("label", ""),
                        "builtIn": True,
                        "path": path,
                    })
                    taken_ids.add(dashboard_id)
            else:
                logger.warning("Presets dir does not exist: %s", self._presets_dir)

        # User dashboards.
        self._ensure_user_dir()
        if self._user_dir and os.path.isdir(self._user_dir):
            for fname in sorted(os.listdir(self._user_dir)):
                if not fname.endswith(".json"):
                    continue
                path = os.path.join(self._user_dir, fname)
                header = self._read_header(path)
                if not header:
                    continue
                dashboard_id = header.get("id", "")
                if not dashboard_id:
                    logger.warning(
                        "Skipping user dashboard with missing id: %s", fname,
                    )
                    continue
                if dashboard_id in taken_ids:
                    logger.warning(
                        "Skipping user dashboard — id collides with built-in: "
                        "%s (%s)", dashboard_id, fname,
                    )
                    continue
                self._dashboards.append({
                    "id": dashboard_id,
                    "label": header.get("label", ""),
                    "builtIn": False,
                    "path": path,
                })
                taken_ids.add(dashboard_id)

        logger.info("Scanned dashboards: %d total", len(self._dashboards))
        self.dashboardsChanged.emit()

    def _read_header(self, absolute_path: str) -> dict:
        full = self._read_full_spec(absolute_path)
        if not full:
            return {}
        return {"id": full.get("id", ""), "label": full.get("label", "")}

    def _read_full_spec(self, absolute_path: str) -> dict:
        try:
            with open(absolute_path, "r", encoding="utf-8") as f:
                data = json.load(f)
        except (OSError, json.JSONDecodeError) as e:
            logger.warning("Cannot read dashboard file %s: %s", absolute_path, e)
            return {}
        if not isinstance(data, dict):
            logger.warning(
                "Dashboard JSON root must be an object: %s", absolute_path,
            )
            return {}
        return data

    def _write_spec(self, absolute_path: str, spec: dict) -> bool:
        directory = os.path.dirname(absolute_path)
        os.makedirs(directory, exist_ok=True)

        try:
            fd, tmp_path = tempfile.mkstemp(
                prefix=".dashboard_tmp_", suffix=".json", dir=directory,
            )
            try:
                with os.fdopen(fd, "w", encoding="utf-8") as f:
                    json.dump(spec, f, indent=2)
                os.replace(tmp_path, absolute_path)
            except Exception:
                # Clean up the temp file if the rename failed.
                try:
                    os.remove(tmp_path)
                except OSError:
                    pass
                raise
        except OSError as e:
            logger.warning("Failed to write dashboard %s: %s", absolute_path, e)
            return False
        return True

    # ------------------------------------------------------------------
    # ID generation (must match C++ slugify / uniqueUserIdFromLabel exactly)
    # ------------------------------------------------------------------

    @staticmethod
    def _slugify(label: str) -> str:
        s = (label or "").lower()
        s = re.sub(r"[^a-z0-9]+", "-", s)
        s = s.strip("-")
        if not s:
            s = "dashboard"
        return s

    def _unique_user_id_from_label(self, label: str) -> str:
        base = self._slugify(label)
        taken = self._existing_ids()
        if base not in taken:
            return base
        for i in range(2, 1000):
            candidate = f"{base}-{i}"
            if candidate not in taken:
                return candidate
        # Astronomically unlikely; last resort.
        return f"{base}-{int(time.time() * 1000)}"
