/**
 * OCTAVE Wiki — Fuzzy Search Engine
 * Client-side full-text search with typo tolerance, word splitting, and heading-level results.
 * No dependencies. Works offline.
 */
(function () {
  "use strict";

  // ── Fuzzy matching core ─────────────────────────────────────────

  /** Levenshtein edit distance (bounded — bails early if > maxDist) */
  function editDistance(a, b, maxDist) {
    if (Math.abs(a.length - b.length) > maxDist) return maxDist + 1;
    var prev = [], curr = [], i, j, cost;
    for (j = 0; j <= b.length; j++) prev[j] = j;
    for (i = 1; i <= a.length; i++) {
      curr[0] = i;
      for (j = 1; j <= b.length; j++) {
        cost = a[i - 1] === b[j - 1] ? 0 : 1;
        curr[j] = Math.min(prev[j] + 1, curr[j - 1] + 1, prev[j - 1] + cost);
      }
      var tmp = prev; prev = curr; curr = tmp;
    }
    return prev[b.length];
  }

  /** Check if query is a fuzzy substring of text (allows edits proportional to length) */
  function fuzzyContains(text, query) {
    if (!query || !text) return { match: false, score: 0 };
    text = text.toLowerCase();
    query = query.toLowerCase();

    // Exact substring — best match
    var idx = text.indexOf(query);
    if (idx !== -1) {
      // Boost for word-boundary match
      var wordStart = idx === 0 || /\W/.test(text[idx - 1]);
      return { match: true, score: wordStart ? 100 : 90, pos: idx };
    }

    // Prefix match on words
    var words = text.split(/\W+/);
    for (var w = 0; w < words.length; w++) {
      if (words[w].indexOf(query) === 0) {
        return { match: true, score: 85, pos: text.indexOf(words[w]) };
      }
    }

    // Fuzzy match — check each word for edit distance
    var maxDist = query.length <= 3 ? 0 : query.length <= 5 ? 1 : 2;
    for (var w2 = 0; w2 < words.length; w2++) {
      if (words[w2].length < 2) continue;
      var d = editDistance(query, words[w2], maxDist);
      if (d <= maxDist) {
        return { match: true, score: 70 - d * 10, pos: text.indexOf(words[w2]) };
      }
      // Also check if query is a fuzzy prefix
      if (words[w2].length >= query.length) {
        d = editDistance(query, words[w2].substring(0, query.length + 1), maxDist);
        if (d <= maxDist) {
          return { match: true, score: 60 - d * 10, pos: text.indexOf(words[w2]) };
        }
      }
    }

    // Subsequence match (all chars appear in order)
    var qi = 0, ti = 0;
    while (qi < query.length && ti < text.length) {
      if (query[qi] === text[ti]) qi++;
      ti++;
    }
    if (qi === query.length && query.length >= 3) {
      var density = query.length / (ti - (text.indexOf(query[0])));
      if (density > 0.4) {
        return { match: true, score: Math.round(40 * density), pos: 0 };
      }
    }

    return { match: false, score: 0 };
  }

  // ── Search function ─────────────────────────────────────────────

  function search(query) {
    if (!query || query.trim().length < 2 || typeof SEARCH_INDEX === "undefined") return [];

    var terms = query.trim().toLowerCase().split(/\s+/).filter(function (t) { return t.length >= 2; });
    if (terms.length === 0) return [];

    var fullQuery = terms.join(" ");
    var results = [];

    for (var p = 0; p < SEARCH_INDEX.length; p++) {
      var page = SEARCH_INDEX[p];
      var pageScore = 0;
      var matchedSections = [];

      // Score title match (highest weight)
      var titleResult = fuzzyContains(page.title, fullQuery);
      if (titleResult.match) {
        pageScore += titleResult.score * 3;
      } else {
        // Try individual terms against title
        for (var t = 0; t < terms.length; t++) {
          var tr = fuzzyContains(page.title, terms[t]);
          if (tr.match) pageScore += tr.score * 2;
        }
      }

      // Score subtitle match
      var subResult = fuzzyContains(page.subtitle, fullQuery);
      if (subResult.match) {
        pageScore += subResult.score * 1.5;
      }

      // Score heading matches
      for (var h = 0; h < page.headings.length; h++) {
        var heading = page.headings[h];
        var hResult = fuzzyContains(heading.text, fullQuery);
        if (!hResult.match) {
          // Try individual terms
          var hTermScore = 0;
          var hTermMatches = 0;
          for (var t2 = 0; t2 < terms.length; t2++) {
            var ht = fuzzyContains(heading.text, terms[t2]);
            if (ht.match) { hTermScore += ht.score; hTermMatches++; }
          }
          if (hTermMatches > 0) {
            hResult = { match: true, score: hTermScore / terms.length };
          }
        }
        if (hResult.match) {
          pageScore += hResult.score * (heading.level === 2 ? 1.2 : 0.8);
          matchedSections.push({
            id: heading.id,
            text: heading.text,
            score: hResult.score
          });
        }
      }

      // Score body content match
      var bodyScore = 0;
      var bodySnippet = "";
      for (var t3 = 0; t3 < terms.length; t3++) {
        var br = fuzzyContains(page.body, terms[t3]);
        if (br.match) {
          bodyScore += br.score;
          if (!bodySnippet && br.pos !== undefined) {
            var start = Math.max(0, br.pos - 60);
            var end = Math.min(page.body.length, br.pos + 120);
            bodySnippet = (start > 0 ? "..." : "") +
              page.body.substring(start, end).trim() +
              (end < page.body.length ? "..." : "");
          }
        }
      }
      if (bodyScore > 0) {
        pageScore += (bodyScore / terms.length) * 0.5;
      }

      if (pageScore > 10) {
        results.push({
          url: page.url,
          title: page.title,
          subtitle: page.subtitle,
          score: Math.round(pageScore),
          sections: matchedSections.sort(function (a, b) { return b.score - a.score; }).slice(0, 4),
          snippet: bodySnippet
        });
      }
    }

    results.sort(function (a, b) { return b.score - a.score; });
    return results.slice(0, 15);
  }

  // ── Highlight matched terms in text ─────────────────────────────

  function highlight(text, query) {
    if (!query || !text) return escapeHtml(text);
    var terms = query.trim().toLowerCase().split(/\s+/);
    var escaped = escapeHtml(text);
    for (var i = 0; i < terms.length; i++) {
      if (terms[i].length < 2) continue;
      var re = new RegExp("(" + escapeRegex(terms[i]) + ")", "gi");
      escaped = escaped.replace(re, '<mark>$1</mark>');
    }
    return escaped;
  }

  function escapeHtml(s) {
    return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
  }

  function escapeRegex(s) {
    return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  }

  // ── UI ──────────────────────────────────────────────────────────

  function createSearchUI() {
    // Search box in sidebar
    var sidebar = document.getElementById("sidebar");
    if (!sidebar) return;

    var searchBox = document.createElement("div");
    searchBox.className = "search-box";
    searchBox.innerHTML =
      '<input type="text" id="search-input" placeholder="Search wiki..." autocomplete="off" spellcheck="false">' +
      '<kbd class="search-shortcut">/</kbd>';

    // Insert after sidebar header
    var header = sidebar.querySelector(".sidebar-header");
    if (header) {
      header.after(searchBox);
    }

    // Results overlay
    var overlay = document.createElement("div");
    overlay.className = "search-overlay";
    overlay.id = "search-overlay";
    overlay.innerHTML = '<div class="search-results" id="search-results"></div>';
    document.body.appendChild(overlay);

    // Events
    var input = document.getElementById("search-input");
    var resultsEl = document.getElementById("search-results");
    var overlayEl = document.getElementById("search-overlay");
    var debounceTimer = null;
    var selectedIndex = -1;

    input.addEventListener("input", function () {
      clearTimeout(debounceTimer);
      debounceTimer = setTimeout(function () {
        var q = input.value.trim();
        if (q.length < 2) {
          hideResults();
          return;
        }
        var results = search(q);
        showResults(results, q);
      }, 150);
    });

    input.addEventListener("keydown", function (e) {
      if (e.key === "Escape") {
        input.value = "";
        hideResults();
        input.blur();
        return;
      }
      if (e.key === "ArrowDown" || e.key === "ArrowUp") {
        e.preventDefault();
        var items = resultsEl.querySelectorAll(".search-result-item");
        if (items.length === 0) return;
        selectedIndex += e.key === "ArrowDown" ? 1 : -1;
        if (selectedIndex < 0) selectedIndex = items.length - 1;
        if (selectedIndex >= items.length) selectedIndex = 0;
        items.forEach(function (el, i) {
          el.classList.toggle("selected", i === selectedIndex);
        });
        items[selectedIndex].scrollIntoView({ block: "nearest" });
        return;
      }
      if (e.key === "Enter") {
        var sel = resultsEl.querySelector(".search-result-item.selected");
        if (sel) {
          var link = sel.querySelector("a");
          if (link) window.location.href = link.href;
        }
        return;
      }
    });

    // Global "/" shortcut
    document.addEventListener("keydown", function (e) {
      if (e.key === "/" && document.activeElement !== input && !e.ctrlKey && !e.metaKey) {
        if (document.activeElement && /input|textarea|select/i.test(document.activeElement.tagName)) return;
        e.preventDefault();
        input.focus();
        input.select();
      }
    });

    // Click overlay to close
    overlayEl.addEventListener("click", function (e) {
      if (e.target === overlayEl) {
        hideResults();
      }
    });

    function showResults(results, query) {
      selectedIndex = -1;
      if (results.length === 0) {
        resultsEl.innerHTML =
          '<div class="search-no-results">No results for <strong>' +
          escapeHtml(query) + '</strong></div>';
        overlayEl.classList.add("visible");
        return;
      }

      var html = '<div class="search-result-count">' + results.length + ' result' +
        (results.length !== 1 ? 's' : '') + '</div>';

      for (var i = 0; i < results.length; i++) {
        var r = results[i];
        html += '<div class="search-result-item" data-index="' + i + '">';
        html += '<a href="' + r.url + '" class="search-result-link">';
        html += '<div class="search-result-title">' + highlight(r.title, query) + '</div>';
        if (r.subtitle) {
          html += '<div class="search-result-subtitle">' + highlight(r.subtitle, query) + '</div>';
        }
        html += '</a>';

        // Sub-section links
        if (r.sections.length > 0) {
          html += '<div class="search-result-sections">';
          for (var s = 0; s < r.sections.length; s++) {
            html += '<a href="' + r.url + '#' + r.sections[s].id + '" class="search-section-link">' +
              highlight(r.sections[s].text, query) + '</a>';
          }
          html += '</div>';
        }

        // Snippet
        if (r.snippet) {
          html += '<div class="search-result-snippet">' + highlight(r.snippet, query) + '</div>';
        }

        html += '</div>';
      }

      resultsEl.innerHTML = html;
      overlayEl.classList.add("visible");

      // Click handlers for result items
      resultsEl.querySelectorAll(".search-result-item").forEach(function (el) {
        el.addEventListener("mouseenter", function () {
          resultsEl.querySelectorAll(".search-result-item").forEach(function (e) {
            e.classList.remove("selected");
          });
          el.classList.add("selected");
          selectedIndex = parseInt(el.dataset.index);
        });
      });
    }

    function hideResults() {
      overlayEl.classList.remove("visible");
      selectedIndex = -1;
    }
  }

  // ── Init ────────────────────────────────────────────────────────

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", createSearchUI);
  } else {
    createSearchUI();
  }
})();
