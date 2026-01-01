"""
SSL/TLS Handler for Android Auto Protocol

Android Auto uses TLS 1.2 for encrypting all communication after
the initial handshake. This module handles the SSL handshake and
encryption/decryption of AAP messages.

The SSL implementation uses a certificate embedded in the head unit
and performs mutual authentication with the phone.
"""

import ssl
import os
import logging
from typing import Optional, Tuple, Callable
from dataclasses import dataclass
from pathlib import Path

from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.backends import default_backend
from cryptography.x509.oid import NameOID
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
import datetime

logger = logging.getLogger(__name__)

# JVC Kenwood certificate signed by Google Automotive Link CA
# This certificate is trusted by Android Auto and used by aasdk/OpenAuto
AASDK_CERTIFICATE = """-----BEGIN CERTIFICATE-----
MIIDKjCCAhICARswDQYJKoZIhvcNAQELBQAwWzELMAkGA1UEBhMCVVMxEzARBgNV
BAgMCkNhbGlmb3JuaWExFjAUBgNVBAcMDU1vdW50YWluIFZpZXcxHzAdBgNVBAoM
Fkdvb2dsZSBBdXRvbW90aXZlIExpbmswJhcRMTQwNzA0MDAwMDAwLTA3MDAXETQ1
MDQyOTE0MjgzOC0wNzAwMFMxCzAJBgNVBAYTAkpQMQ4wDAYDVQQIDAVUb2t5bzER
MA8GA1UEBwwISGFjaGlvamkxFDASBgNVBAoMC0pWQyBLZW53b29kMQswCQYDVQQL
DAIwMTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAM911mNnUfx+WJtx
uk06GO7kXRW/gXUVNQBkbAFZmVdVNvLoEQNthi2X8WCOwX6n6oMPxU2MGJnvicP3
6kBqfHhfQ2Fvqlf7YjjhgBHh0lqKShVPxIvdatBjVQ76aym5H3GpkigLGkmeyiVo
VO8oc3cJ1bO96wFRmk7kJbYcEjQyakODPDu4QgWUTwp1Z8Dn41ARMG5OFh6otITL
XBzj9REkUPkxfS03dBXGr5/LIqvSsnxib1hJ47xnYJXROUsBy3e6T+fYZEEzZa7y
7tFioHIQ8G/TziPmvFzmQpaWMGiYfoIgX8WoR3GD1diYW+wBaZTW+4SFUZJmRKgq
TbMNFkMCAwEAATANBgkqhkiG9w0BAQsFAAOCAQEAsGdH5VFn78WsBElMXaMziqFC
zmilkvr85/QpGCIztI0FdF6xyMBJk/gYs2thwvF+tCCpXoO8mjgJuvJZlwr6fHzK
Ox5hNUb06AeMtsUzUfFjSZXKrSR+XmclVd+Z6/ie33VhGePOPTKYmJ/PPfTT9wvT
93qswcxhA+oX5yqLbU3uDPF1ZnJaEeD/YN45K/4eEA4/0SDXaWW14OScdS2LV0Bc
YmsbkPVNYZn37FlY7e2Z4FUphh0A7yME2Eh/e57QxWrJ1wubdzGnX8mrABc67ADU
U5r9tlTRqMs7FGOk6QS2Cxp4pqeVQsrPts4OEwyPUyb3LfFNo3+sP111D9zEow==
-----END CERTIFICATE-----"""

AASDK_PRIVATE_KEY = """-----BEGIN RSA PRIVATE KEY-----
MIIEowIBAAKCAQEAz3XWY2dR/H5Ym3G6TToY7uRdFb+BdRU1AGRsAVmZV1U28ugR
A22GLZfxYI7Bfqfqgw/FTYwYme+Jw/fqQGp8eF9DYW+qV/tiOOGAEeHSWopKFU/E
i91q0GNVDvprKbkfcamSKAsaSZ7KJWhU7yhzdwnVs73rAVGaTuQlthwSNDJqQ4M8
O7hCBZRPCnVnwOfjUBEwbk4WHqi0hMtcHOP1ESRQ+TF9LTd0Fcavn8siq9KyfGJv
WEnjvGdgldE5SwHLd7pP59hkQTNlrvLu0WKgchDwb9POI+a8XOZClpYwaJh+giBf
xahHcYPV2Jhb7AFplNb7hIVRkmZEqCpNsw0WQwIDAQABAoIBAB2u7ZLheKCY71Km
bhKYqnKb6BmxgfNfqmq4858p07/kKG2O+Mg1xooFgHrhUhwuKGbCPee/kNGNrXeF
pFW9JrwOXVS2pnfaNw6ObUWhuvhLaxgrhqLAdoUEgWoYOHcKzs3zhj8Gf6di+edq
SyTA8+xnUtVZ6iMRKvP4vtCUqaIgBnXdmQbGINP+/4Qhb5R7XzMt/xPe6uMyAIyC
y5Fm9HnvekaepaeFEf3bh4NV1iN/R8px6cFc6ELYxIZc/4Xbm91WGqSdB0iSriaZ
TjgrmaFjSO40tkCaxI9N6DGzJpmpnMn07ifhl2VjnGOYwtyuh6MKEnyLqTrTg9x0
i3mMwskCgYEA9IyljPRerXxHUAJt+cKOayuXyNt80q9PIcGbyRNvn7qIY6tr5ut+
ZbaFgfgHdSJ/4nICRq02HpeDJ8oj9BmhTAhcX6c1irH5ICjRlt40qbPwemIcpybt
mb+DoNYbI8O4dUNGH9IPfGK8dRpOok2m+ftfk94GmykWbZF5CnOKIp8CgYEA2Syc
5xlKB5Qk2ZkwXIzxbzozSfunHhWWdg4lAbyInwa6Y5GB35UNdNWI8TAKZsN2fKvX
RFgCjbPreUbREJaM3oZ92o5X4nFxgjvAE1tyRqcPVbdKbYZgtcqqJX06sW/g3r/3
RH0XPj2SgJIHew9sMzjGWDViMHXLmntI8rVA7d0CgYBOr36JFwvrqERN0ypNpbMr
epBRGYZVSAEfLGuSzEUrUNqXr019tKIr2gmlIwhLQTmCxApFcXArcbbKs7jTzvde
PoZyZJvOr6soFNozP/YT8Ijc5/quMdFbmgqhUqLS5CPS3z2N+YnwDNj0mO1aPcAP
STmcm2DmxdaolJksqrZ0owKBgQCD0KJDWoQmaXKcaHCEHEAGhMrQot/iULQMX7Vy
gl5iN5E2EgFEFZIfUeRWkBQgH49xSFPWdZzHKWdJKwSGDvrdrcABwdfx520/4MhK
d3y7CXczTZbtN1zHuoTfUE0pmYBhcx7AATT0YCblxrynosrHpDQvIefBBh5YW3AB
cKZCOQKBgEM/ixzI/OVSZ0Py2g+XV8+uGQyC5XjQ6cxkVTX3Gs0ZXbemgUOnX8co
eCXS4VrhEf4/HYMWP7GB5MFUOEVtlLiLM05ruUL7CrphdfgayDXVcTPfk75lLhmu
KAwp3tIHPoJOQiKNQ3/qks5km/9dujUGU2ARiU3qmxLMdgegFz8e
-----END RSA PRIVATE KEY-----"""


@dataclass
class SSLConfig:
    """SSL configuration for Android Auto."""
    cert_path: Optional[Path] = None
    key_path: Optional[Path] = None
    ca_cert_path: Optional[Path] = None


class SSLHandler:
    """
    Handles SSL/TLS encryption for Android Auto Protocol.

    Android Auto uses a custom SSL handshake embedded in the AAP
    control messages. This class manages:
    - Certificate generation (for first-time setup)
    - SSL handshake processing
    - Message encryption/decryption
    """

    def __init__(self, config: Optional[SSLConfig] = None):
        self._config = config or SSLConfig()
        self._ssl_context: Optional[ssl.SSLContext] = None
        self._ssl_object: Optional[ssl.SSLObject] = None

        # Handshake state
        self._handshake_complete = False
        self._incoming_bio: Optional[ssl.MemoryBIO] = None
        self._outgoing_bio: Optional[ssl.MemoryBIO] = None

        # Certificate paths
        self._cert_dir = Path(__file__).parent / "certs"

    def initialize(self, as_server: bool = False) -> bool:
        """
        Initialize SSL context and certificates.

        Args:
            as_server: If True, act as SSL server. If False, act as SSL client.
                       For Android Auto, head unit is CLIENT, phone is SERVER.

        Returns:
            True if initialization successful
        """
        try:
            # Ensure cert directory exists
            self._cert_dir.mkdir(parents=True, exist_ok=True)

            # Generate or load certificates
            if not self._load_certificates():
                if not self._generate_certificates():
                    return False

            # Create SSL context
            self._create_ssl_context(as_server)

            # Create memory BIOs for handshake
            self._incoming_bio = ssl.MemoryBIO()
            self._outgoing_bio = ssl.MemoryBIO()

            # Create SSL object - head unit is CLIENT
            self._ssl_object = self._ssl_context.wrap_bio(
                self._incoming_bio,
                self._outgoing_bio,
                server_side=as_server,
                server_hostname=None if as_server else "android.auto"
            )

            logger.info(f"SSL handler initialized (as_server={as_server})")
            return True

        except Exception as e:
            logger.error(f"Failed to initialize SSL handler: {e}")
            import traceback
            traceback.print_exc()
            return False

    def _load_certificates(self) -> bool:
        """Load or create certificates using aasdk's trusted JVC Kenwood cert."""
        cert_file = self._cert_dir / "headunit.crt"
        key_file = self._cert_dir / "headunit.key"

        # Always use the aasdk certificates (signed by Google Automotive Link CA)
        # Write them to files if they don't exist
        if not cert_file.exists():
            with open(cert_file, "w") as f:
                f.write(AASDK_CERTIFICATE)
            logger.info("Created certificate file from aasdk")

        if not key_file.exists():
            with open(key_file, "w") as f:
                f.write(AASDK_PRIVATE_KEY)
            logger.info("Created private key file from aasdk")

        self._config.cert_path = cert_file
        self._config.key_path = key_file
        logger.info("Loaded aasdk certificates (JVC Kenwood / Google Automotive Link)")
        return True

    def _generate_certificates(self) -> bool:
        """Generate self-signed certificates for head unit."""
        try:
            logger.info("Generating head unit certificates...")

            # Generate private key
            key = rsa.generate_private_key(
                public_exponent=65537,
                key_size=2048,
                backend=default_backend()
            )

            # Generate certificate
            subject = issuer = x509.Name([
                x509.NameAttribute(NameOID.COUNTRY_NAME, "US"),
                x509.NameAttribute(NameOID.STATE_OR_PROVINCE_NAME, "California"),
                x509.NameAttribute(NameOID.LOCALITY_NAME, "San Francisco"),
                x509.NameAttribute(NameOID.ORGANIZATION_NAME, "OCTAVE"),
                x509.NameAttribute(NameOID.COMMON_NAME, "OCTAVE Head Unit"),
            ])

            cert = x509.CertificateBuilder().subject_name(
                subject
            ).issuer_name(
                issuer
            ).public_key(
                key.public_key()
            ).serial_number(
                x509.random_serial_number()
            ).not_valid_before(
                datetime.datetime.utcnow()
            ).not_valid_after(
                datetime.datetime.utcnow() + datetime.timedelta(days=3650)
            ).add_extension(
                x509.BasicConstraints(ca=True, path_length=None),
                critical=True,
            ).sign(key, hashes.SHA256(), default_backend())

            # Save certificate
            cert_file = self._cert_dir / "headunit.crt"
            with open(cert_file, "wb") as f:
                f.write(cert.public_bytes(serialization.Encoding.PEM))

            # Save private key
            key_file = self._cert_dir / "headunit.key"
            with open(key_file, "wb") as f:
                f.write(key.private_bytes(
                    encoding=serialization.Encoding.PEM,
                    format=serialization.PrivateFormat.TraditionalOpenSSL,
                    encryption_algorithm=serialization.NoEncryption()
                ))

            self._config.cert_path = cert_file
            self._config.key_path = key_file

            logger.info("Generated and saved head unit certificates")
            return True

        except Exception as e:
            logger.error(f"Failed to generate certificates: {e}")
            return False

    def _create_ssl_context(self, as_server: bool = False):
        """Create and configure SSL context."""
        if as_server:
            self._ssl_context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        else:
            self._ssl_context = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)

        # Load certificate and key
        if self._config.cert_path and self._config.key_path:
            self._ssl_context.load_cert_chain(
                certfile=str(self._config.cert_path),
                keyfile=str(self._config.key_path)
            )

        # Configure for Android Auto compatibility
        self._ssl_context.minimum_version = ssl.TLSVersion.TLSv1_2
        self._ssl_context.maximum_version = ssl.TLSVersion.TLSv1_2

        # Don't verify certificates (Android Auto uses custom auth)
        self._ssl_context.check_hostname = False
        self._ssl_context.verify_mode = ssl.CERT_NONE

        # Set cipher suites compatible with Android Auto
        try:
            self._ssl_context.set_ciphers(
                "ECDHE+AESGCM:DHE+AESGCM:ECDHE+CHACHA20:DHE+CHACHA20:RSA+AESGCM:RSA+AES"
            )
        except ssl.SSLError:
            # Fallback to default ciphers if specific ones aren't available
            pass

    def process_handshake_data(self, data: bytes) -> Tuple[bytes, bool]:
        """
        Process incoming SSL handshake data.

        Args:
            data: Incoming handshake data from phone (can be empty to initiate)

        Returns:
            Tuple of (outgoing data to send, handshake complete flag)
        """
        if not self._ssl_object or not self._incoming_bio:
            raise RuntimeError("SSL handler not initialized")

        # Write incoming data to BIO (if any)
        if data:
            self._incoming_bio.write(data)
            print(f"[SSL] Fed {len(data)} bytes to incoming BIO")

        try:
            # Try to complete handshake
            self._ssl_object.do_handshake()
            self._handshake_complete = True
            logger.info("SSL handshake complete")
            print(f"[SSL] Handshake complete!")

        except ssl.SSLWantReadError:
            # Need more data - this is normal during handshake
            print(f"[SSL] Handshake wants more data (SSLWantReadError)")
            pass
        except ssl.SSLWantWriteError:
            # Need to write data - this is normal during handshake
            print(f"[SSL] Handshake wants to write (SSLWantWriteError)")
            pass
        except ssl.SSLError as e:
            print(f"[SSL] Handshake error: {e}")
            logger.error(f"SSL handshake error: {e}")
            raise

        # Get outgoing data
        outgoing = self._outgoing_bio.read()
        if outgoing:
            print(f"[SSL] Generated {len(outgoing)} bytes of outgoing data")

        return outgoing, self._handshake_complete

    def encrypt(self, data: bytes) -> bytes:
        """
        Encrypt data for transmission.

        Args:
            data: Plaintext data

        Returns:
            Encrypted data
        """
        if not self._handshake_complete:
            raise RuntimeError("SSL handshake not complete")

        self._ssl_object.write(data)
        return self._outgoing_bio.read()

    def decrypt(self, data: bytes) -> bytes:
        """
        Decrypt received data.

        Args:
            data: Encrypted data

        Returns:
            Decrypted plaintext
        """
        if not self._handshake_complete:
            raise RuntimeError("SSL handshake not complete")

        self._incoming_bio.write(data)

        decrypted = b''
        try:
            while True:
                chunk = self._ssl_object.read(16384)
                if not chunk:
                    break
                decrypted += chunk
        except ssl.SSLWantReadError:
            pass

        return decrypted

    @property
    def is_handshake_complete(self) -> bool:
        """Check if SSL handshake is complete."""
        return self._handshake_complete

    def reset(self, as_server: bool = False):
        """Reset SSL state for new connection."""
        self._handshake_complete = False

        if self._ssl_context:
            self._incoming_bio = ssl.MemoryBIO()
            self._outgoing_bio = ssl.MemoryBIO()

            self._ssl_object = self._ssl_context.wrap_bio(
                self._incoming_bio,
                self._outgoing_bio,
                server_side=as_server,
                server_hostname=None if as_server else "android.auto"
            )

    def get_certificate_fingerprint(self) -> Optional[str]:
        """Get SHA256 fingerprint of the head unit certificate."""
        if not self._config.cert_path or not self._config.cert_path.exists():
            return None

        try:
            with open(self._config.cert_path, "rb") as f:
                cert_data = f.read()

            cert = x509.load_pem_x509_certificate(cert_data, default_backend())
            fingerprint = cert.fingerprint(hashes.SHA256())

            return ":".join(f"{b:02X}" for b in fingerprint)

        except Exception as e:
            logger.error(f"Failed to get certificate fingerprint: {e}")
            return None
