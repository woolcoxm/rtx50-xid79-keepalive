"""Keeps a small CUDA context open on the NVIDIA card from sign-in until shutdown.

Why: some RTX 50 cards drop off the PCIe bus ("GPU is lost", nvlddmkm event 153 "BusReset TDR
occurred on GPUID:100") when a large load hits them from the fully idle state. With another
process holding a CUDA context on the card, one such RTX 5070 Ti stopped doing that (see
../README.md for the tests and their limits). This script is that other process.

This is the original version, the one running on the card owner's PC. GpuKeepAlive.exe in the
folder above does the same thing without Python. Written by an AI assistant (ZCode, running
GLM 5.4 from Z.ai) at the owner's request; the owner did not find the workaround or write this.

It only holds 256 MiB of memory on the card; it does no computing. Runs hidden (pythonw)
and writes gpu_keepalive.log next to this file.

    pythonw.exe gpu_keepalive.py             normal use, no window
    python.exe  gpu_keepalive.py --status    show recent log lines
"""
import ctypes
import os
import sys
import time
from datetime import datetime

HERE = os.path.dirname(os.path.abspath(__file__))
LOG = os.path.join(HERE, "gpu_keepalive.log")
RESERVE_BYTES = 256 * 1024 * 1024
ERROR_ALREADY_EXISTS = 183


def log(msg):
    try:
        with open(LOG, "a", encoding="utf-8", newline="\n") as f:
            f.write(f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S')} {msg}\n")
    except OSError:
        pass


def exported(dll, name):
    """Take the current (_v2) entry point where one exists: on driver 610.88 the old unsuffixed
    memory calls return "invalid device context" even with a valid context set."""
    if hasattr(dll, name + "_v2"):
        return getattr(dll, name + "_v2")
    return getattr(dll, name)


class Cuda:
    """Just enough of the CUDA driver interface (nvcuda.dll ships with the NVIDIA driver)."""

    def __init__(self):
        dll = ctypes.WinDLL("nvcuda.dll")
        u, i, p, s = ctypes.c_uint, ctypes.c_int, ctypes.c_void_p, ctypes.c_size_t
        self.cuInit = exported(dll, "cuInit")
        self.cuDeviceGet = exported(dll, "cuDeviceGet")
        self.cuDevicePrimaryCtxRetain = exported(dll, "cuDevicePrimaryCtxRetain")
        self.cuCtxSetCurrent = exported(dll, "cuCtxSetCurrent")
        self.cuMemAlloc = exported(dll, "cuMemAlloc")
        self.cuMemsetD8 = exported(dll, "cuMemsetD8")
        self.cuMemGetInfo = exported(dll, "cuMemGetInfo")
        self.cuInit.argtypes = [u]
        self.cuDeviceGet.argtypes = [ctypes.POINTER(i), i]
        self.cuDevicePrimaryCtxRetain.argtypes = [ctypes.POINTER(p), i]
        self.cuCtxSetCurrent.argtypes = [p]
        self.cuMemAlloc.argtypes = [ctypes.POINTER(ctypes.c_uint64), s]
        self.cuMemsetD8.argtypes = [ctypes.c_uint64, u, s]
        self.cuMemGetInfo.argtypes = [ctypes.POINTER(s), ctypes.POINTER(s)]
        dll.cuGetErrorString.argtypes = [i, ctypes.POINTER(ctypes.c_char_p)]
        dll.cuGetErrorString.restype = i
        self.dll = dll
        self.ctx = ctypes.c_void_p()
        self.block = ctypes.c_uint64()

    def text(self, code):
        buf = ctypes.c_char_p()
        self.dll.cuGetErrorString(code, ctypes.byref(buf))
        return buf.value.decode("ascii", "replace") if buf.value else "unknown error"

    def hold(self):
        """Create a context on the card and fill 256 MiB in it. Returns 0, or the CUDA error."""
        code = self.cuInit(0)
        if code:
            return code
        dev = ctypes.c_int()
        code = self.cuDeviceGet(ctypes.byref(dev), 0)
        if code:
            return code
        code = self.cuDevicePrimaryCtxRetain(ctypes.byref(self.ctx), dev)
        if code:
            return code
        code = self.cuCtxSetCurrent(self.ctx)
        if code:
            return code
        code = self.cuMemAlloc(ctypes.byref(self.block), RESERVE_BYTES)
        if code:
            return code
        return self.cuMemsetD8(self.block, 0, RESERVE_BYTES)

    def ping(self):
        free, total = ctypes.c_size_t(), ctypes.c_size_t()
        return self.cuMemGetInfo(ctypes.byref(free), ctypes.byref(total))


def single_instance():
    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel32.CreateMutexW.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_wchar_p]
    kernel32.CreateMutexW.restype = ctypes.c_void_p
    kernel32.CreateMutexW(None, 1, "Local\\GpuKeepAliveXid79")
    return ctypes.get_last_error() != ERROR_ALREADY_EXISTS


def main():
    if "--status" in sys.argv:
        try:
            with open(LOG, encoding="utf-8", errors="replace") as f:
                sys.stdout.reconfigure(encoding="utf-8", errors="replace")
                sys.stdout.write("".join(f.read().splitlines(True)[-15:]))
        except OSError as e:
            print(f"no log yet ({e})")
        return 0
    if not single_instance():
        return 0
    cuda, held, was_ok = Cuda(), False, None
    log(f"started (pid {os.getpid()})")
    while True:
        if not held:
            code = cuda.hold()
            if code == 0:
                held, was_ok = True, True
                log("holding a 256 MiB CUDA context on the card")
            else:
                if was_ok is not False:
                    log(f"card not available yet: {code} {cuda.text(code)}")
                was_ok = False
                time.sleep(5)
                continue
        time.sleep(15)
        code = cuda.ping()
        ok = code == 0
        if ok != was_ok:
            log("card is answering again" if ok else f"CARD STOPPED ANSWERING: {code} {cuda.text(code)}")
            was_ok = ok
            if not ok:
                held = False   # rebuild the context once the card is back (after a restart)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as e:  # noqa: BLE001 - this runs unattended; never show a window
        log(f"stopped by an error: {type(e).__name__}: {e}")
        sys.exit(1)
