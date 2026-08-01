#!/bin/sh
# =========================================================
# Smart Dependency Installer (Silent Feed Scan)
# =========================================================

# ---------------------------------------------------------
# Detect package manager
# ---------------------------------------------------------
if [ -f /etc/opkg/opkg.conf ]; then
    PM="opkg"
    INSTALL="opkg install"
    UPDATE="opkg update"
    STATUS="opkg status"
    LIST="opkg list"
elif command -v apt-get >/dev/null 2>&1; then
    PM="apt"
    INSTALL="apt-get install -y"
    UPDATE="apt-get update"
    STATUS="dpkg -s"
    LIST="apt-cache search"
else
    echo "Unsupported system (opkg or apt required)"
    exit 1
fi

# ---------------------------------------------------------
# Pretty messages
# ---------------------------------------------------------
print_msg() { echo "[INFO] $1"; }
print_ok()   { echo "[ OK ] $1"; }
print_fail() { echo "[FAIL] $1"; }

echo "======================================"
echo " Smart Dependency Installer"
echo "======================================"
echo ""

print_msg "Updating feeds..."
$UPDATE > /dev/null 2>&1

# ---------------------------------------------------------
# Detect Python version
# ---------------------------------------------------------
PYVER=$(python3 -c "from sys import version_info; print(version_info[0])" 2>/dev/null)
[ -z "$PYVER" ] && PYVER=2
echo "Detected Python: $PYVER"
echo ""

# ---------------------------------------------------------
# Base dependencies
# ---------------------------------------------------------
DEPS="wget alsa-conf alsa-state alsa-plugins alsa-utils alsa-utils-aplay astra-sm bzip2 binutils curl duktape dvbsnoop enigma2 enigma2-plugin-extensions-e2iplayer-deps exteplayer3 ffmpeg gstplayer perl-module-io-zlib libasound2 libusb-1.0-0 libxml2 libxslt libc6 libgcc1 libstdc++6 openvpn rtmpdump transmission transmission-client enigma2-plugin-systemplugins-serviceapp unrar zip xz zstd gstreamer1.0-plugins-good gstreamer1.0-plugins-base gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly python3-core python3-twisted-web python3-pillow python3-json"

# ---------------------------------------------------------
# Python specific - Updated for Python 3.13/3.14
# ---------------------------------------------------------
if [ "$PYVER" = "3" ]; then
    # Base Python 3 packages (updated names for 3.13/3.14)
    DEPS="$DEPS livestreamersrv"
    
    # Python 3.13/3.14 compatible packages
    PY3_DEPS="python3-backports-lzma python3-beautifulsoup4 python3-certifi python3-chardet python3-cfscrape python3-codecs python3-compression python3-cryptography python3-dateutil python3-difflib python3-fuzzywuzzy python3-future python3-futures3 python3-html python3-image python3-js2py python3-levenshtein python3-lxml python3-mmap python3-misc python3-mechanize python3-multiprocessing python3-netclient python3-netserver python3-pkgutil python3-pycurl python3-pycryptodome python3-pydoc python3-pyexecjs python3-pyopenssl python3-rarfile python3-pysocks python3-requests python3-requests-cache python3-shell python3-sqlite3 python3-six python3-treq python3-transmission-rpc python3-unixadmin python3-urllib3 python3-xmlrpc python3-zoneinfo"
    
    DEPS="$DEPS $PY3_DEPS"
    
    # Versioned libraries - Updated for Python 3.13 and 3.14
    VERSIONED_LIBS="libavcodec60 libavcodec61 libavcodec62 libavcodec63 libavformat60 libavformat61 libavformat62 libavformat63"
    
    # Python 3.13/3.14 specific libraries
    PY3_LIBS="libpython3.13-1.0 libpython3.14-1.0"
    
    # Add Python 3.11/3.12 for backward compatibility
    PY3_LIBS="$PY3_LIBS libpython3.11-1.0 libpython3.12-1.0"
    
    VERSIONED_LIBS="$VERSIONED_LIBS $PY3_LIBS"
    
    # Check which libraries are available in feeds
    FEED_LIST=$($LIST 2>/dev/null)
    AVAILABLE_LIBS=""
    NOT_AVAILABLE_LIBS=""
    
    for pkg in $VERSIONED_LIBS; do
        if echo "$FEED_LIST" | grep -q "^$pkg "; then
            AVAILABLE_LIBS="$AVAILABLE_LIBS $pkg"
        else
            NOT_AVAILABLE_LIBS="$NOT_AVAILABLE_LIBS $pkg"
        fi
    done
else
    # Python 2 (legacy support)
    DEPS="$DEPS f4mdump hlsdl kodi-addon-pvr-iptvsimple python-lzma python-argparse python-beautifulsoup4 python-certifi python-chardet python-codecs python-compression python-core python-pycurl python-cryptography python-difflib python-futures python-html python-image python-imaging python-json python-js2py python-lxml python-mechanize python-multiprocessing python-misc python-mmap python-ndg-httpsclient python-netclient python-pycrypto python-pyexecjs python-pydoc python-pyopenssl python-requests python-robotparser python-six python-shell python-sqlite3 python-pysocks python-subprocess python-twisted-web python-unixadmin python-urllib3 python-xmlrpc python-libs libpython2.7-1.0 libavcodec58 libavformat58"
fi

# ---------------------------------------------------------
# Counters
# ---------------------------------------------------------
INSTALLED=0
INSTALLED_NOW=0
FAILED=0

# ---------------------------------------------------------
# Install main dependencies
# ---------------------------------------------------------
for pkg in $DEPS; do
    # Skip packages that are known to cause issues with Python 3.13/3.14
    if [ "$PYVER" = "3" ] && echo "$pkg" | grep -q "python3-cfscrape"; then
        print_msg "Skipping $pkg (known compatibility issues with Python 3.13/3.14)"
        continue
    fi
    
    if $STATUS $pkg 2>/dev/null | grep -q "install ok installed"; then
        print_ok "$pkg already installed"
        INSTALLED=$((INSTALLED + 1))
        continue
    fi
    
    print_msg "Installing $pkg ..."
    $INSTALL $pkg > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        print_ok "$pkg installed"
        INSTALLED_NOW=$((INSTALLED_NOW + 1))
    else
        print_fail "$pkg failed"
        FAILED=$((FAILED + 1))
    fi
    sleep 1
done

# ---------------------------------------------------------
# Install versioned libs (PY3 only)
# ---------------------------------------------------------
if [ "$PYVER" = "3" ]; then
    echo ""
    print_msg "Installing compatible libraries for Python 3.13/3.14..."
    
    for pkg in $AVAILABLE_LIBS; do
        if $STATUS $pkg 2>/dev/null | grep -q "install ok installed"; then
            print_ok "$pkg already installed"
            INSTALLED=$((INSTALLED + 1))
            continue
        fi
        
        print_msg "Installing $pkg ..."
        $INSTALL $pkg > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            print_ok "$pkg installed"
            INSTALLED_NOW=$((INSTALLED_NOW + 1))
        else
            print_fail "$pkg failed"
            FAILED=$((FAILED + 1))
        fi
        sleep 1
    done
    
    # Post-installation Python 3.13/3.14 specific fixes
    print_msg "Applying Python 3.13/3.14 compatibility fixes..."
    
    # Try to install missing dependencies using pip if available
    if command -v pip3 >/dev/null 2>&1; then
        print_msg "Installing Python 3.13/3.14 packages via pip (fallback)..."
        pip3 install --no-cache-dir --upgrade pip > /dev/null 2>&1
        pip3 install --no-cache-dir requests beautifulsoup4 lxml pillow > /dev/null 2>&1
    fi
fi

# ---------------------------------------------------------
# Summary
# ---------------------------------------------------------
echo ""
echo "======================================"
echo " Already Installed : $INSTALLED"
echo " Installed Now     : $INSTALLED_NOW"
echo " Failed            : $FAILED"
echo "======================================"

if [ $FAILED -gt 0 ]; then
    echo ""
    print_msg "Some packages failed to install. This is normal for Python 3.13/3.14"
    print_msg "as some packages may have been deprecated or renamed."
    print_msg "The script attempted pip fallback for critical packages."
fi