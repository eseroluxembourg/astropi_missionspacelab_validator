#!/bin/bash

file_path="./main.py"

timeout_duration=600  # 10 minutes in seconds

# Maximum allowed size in megabytes
max_size=250

# Forbidden libraries
forbidden_libraries=(
    "struct" "codecs" "stat" "tempfile" "linecache" "pickle" "copyreg" "shelve"
    "marshal" "hmac" "secrets" "getpass" "curses" "curses.textpad" "curses.ascii"
    "curses.panel" "ctypes" "multiprocessing" "multiprocessing.shared_memory"
    "concurrent.futures" "subprocess" "_thread" "asyncio" "socket" "ssl" "select"
    "selectors" "signal" "mmap" "email" "mailbox" "binascii" "quopri" "html"
    "html.parser" "html.entities" "xml.etree.ElementTree" "xml.dom" "xml.dom.minidom"
    "xml.dom.pulldom" "xml.sax" "xml.sax.handler" "xml.sax.saxutils" "xml.sax.xmlreader"
    "xml.parsers.expat" "webbrowser" "wsgiref" "urllib" "urllib.request" "urllib.response"
    "urllib.parse" "urllib.error" "urllib.robotparser" "http" "http.client" "ftplib"
    "poplib" "imaplib" "smtplib" "socketserver" "http.server" "http.cookies"
    "http.cookiejar" "xmlrpc" "xmlrpc.client" "xmlrpc.server" "ipaddress" "wave"
    "turtle" "cmd" "shlex" "tkinter" "tkinter.colorchooser" "tkinter.font" "tkinter.messagebox"
    "tkinter.scrolledtext" "tkinter.dnd" "tkinter.ttk" "tkinter.tix" "pydoc" "doctest"
    "unittest" "unittest.mock" "2to3" "test" "test.support" "test.support.socket_helper"
    "test.support.script_helper" "test.support.bytecode_helper" "test.support.threading_helper"
    "test.support.os_helper" "test.support.import_helper" "test.support.warnings_helper"
    "bdb" "pdb" "timeit" "trace" "tracemalloc" "distutils" "ensurepip" "venv" "zipapp"
    "sysconfig" "__future__" "gc" "inspect" "site" "code" "codeop" "zipimport" "pkgutil"
    "modulefinder" "runpy" "importlib" "importlib.resources" "importlib.resources.abc"
    "importlib.metadata" "ast" "symtable" "token" "keyword" "tokenize" "tabnanny" "pyclbr"
    "py_compile" "compileall" "dis" "pickletools" "msvcrt" "winreg" "winsound" "posix"
    "pwd" "grp" "termios" "tty" "pty" "fcntl" "resource" "syslog" "aifc" "asynchat"
    "asyncore" "audioop" "cgi" "cgitb" "chunk" "crypt" "imghdr" "imp" "mailcap" "msilib"
    "nis" "nntplib" "optparse" "ossaudiodev" "pipes" "smtpd" "sndhdr" "spwd" "sunau"
    "telnetlib" "uu" "xdrlib" "zlib" "gzip" "bz2" "lzma" "zipfile" "tarfile"
)

# Define the list of allowed extensions after successfull run 
allowed_extensions=".csv\|.txt\|.log\|.jpg\|.png\|.yuv\|.raw\|.h264\|.json\|.toml\|.yaml"

# Function to check for forbidden libraries
check_forbidden_libraries() {
    for library in "${forbidden_libraries[@]}"; do
        grep -R -q "\b${library}\b" "$1"
        if [ $? -eq 0 ]; then
            echo "Forbidden library '$library' found in $1"
            exit 1
        fi
    done
}

if [ -e "$file_path" ]; then

    # Check Python syntax errors
    python3 -m py_compile "$file_path"
    syntax_error=$?

    if [ $syntax_error -eq 0 ]; then
	
        # Check for forbidden libraries
        check_forbidden_libraries "$file_path"

		# Check if stdout and stderr are redirected to /dev/null in main.py
		if grep -qE '>/dev/null\s*2>&1|2>&1\s*>/dev/null' "$file_path"; then
			continue 
		else
			echo "main.py does not redirect both stdout and stderr to /dev/null."
			exit 1
		fi
		
		# Check if main.py attempts to create new directories or uses absolute path names
		if grep -qE 'makedirs|mkdir|open\(|\s\/' "$file_path"; then
			echo "main.py attempts to create new directories or uses absolute path names."
			exit 1
		fi

		# Check for files in the current directory
		files=$(ls)

		# Check each file's name using grep
		invalid_files=$(echo "$files" | grep -vE '^[a-zA-Z0-9._-]+$')

		# check that in the current folder, existing files only include letters, numbers, dots, dashes or underscores
		if [ -z "$invalid_files" ]; then
			continue
		else
			echo "The following files in the current directory have invalid names:"
			echo "$invalid_files"
			exit 1
		fi

		# Check if main.py uses vcgencmd
		if grep -q "vcgencmd" "$file_path"; then
			echo "Error: main.py uses vcgencmd, which is not allowed."
			exit 1
		else
			echo "main.py does not use vcgencmd."
		fi

        # Execute the Python code
        timeout "$timeout_duration" python3 "$file_path"
        exit_code=$?

        if [ $exit_code -eq 0 ]; then
            continue
        elif [ $exit_code -eq 124 ]; then
            echo "Execution of main.py takes more than 10 minutes."
            exit 1
        else
            echo "Execution of main.py returned an error with exit code $exit_code."
            exit 1
        fi
    else
        echo "main.py contains syntax errors. Please fix them before executing."
        exit 1
    fi
else
    echo "main.py does not exist in the root folder."
    exit 1
fi

# Check if result.txt exists and is non-empty
if [ ! -s "$output_file" ] || [ $(wc -l < "$output_file") -ne 1 ]; then
    echo "main.py did not produce the expected result.txt file with a single line."
    exit 1
fi

# Check that the result.txt file contains only one line with exactly five digits in total, including the decimal sign 
line=$(head -n 1 "$output_file")
if [[ ! "$line" =~ ^[0-9]+(\.[0-9]+)?$ ]] || [ $(echo "$line" | grep -o '[0-9]' | wc -l) -ne 5 ]; then
    echo "main.py did not produce the expected result.txt file with five digits in total."
    exit 1
fi

# Check for files in the current directory with disallowed extensions
invalid_files=$(ls | grep -vE "\.($allowed_extensions)$")

if [ -z "$invalid_files" ]; then
    continue
else
    echo "The following files in the current directory have disallowed extensions:"
    echo "$invalid_files"
    exit 1
fi

# check that all the files in the current folder does not use more than 250MB of space

# Calculate total size of current directory and its contents
total_size=$(du -s -BM . | awk '{print $1}' | tr -d 'M')

if [ "$total_size" -le "$max_size" ]; then
    continue
else
    echo "Total size of files in the current directory exceeds the limit."
    exit 1
fi

echo "SUCCESS"
