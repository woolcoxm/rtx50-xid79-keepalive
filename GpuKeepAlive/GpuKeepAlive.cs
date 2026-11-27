// GpuKeepAlive - keeps a small CUDA context open on the first NVIDIA GPU, from sign-in until shutdown.
//
// Why: one RTX 5070 Ti kept dropping off the PCIe bus ("GPU is lost", nvlddmkm event 153
// "BusReset TDR occurred on GPUID:100") whenever a large load hit it from the fully idle state.
// With any process holding a CUDA context on the card, it stopped doing that. See README.md.
//
// This program is that process. It holds 256 MiB on the card and does no computing.
// It talks to nvcuda.dll (shipped with every NVIDIA driver) and needs nothing else.
// Build it yourself with build.cmd (uses the C# compiler that comes with Windows).
//
// Written by an AI assistant (ZCode, running GLM 5.4 from Z.ai) at the direction of the card's
// owner, who did not find the workaround or write this code. MIT licence, see ../LICENSE.

using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

static class GpuKeepAlive
{
    const uint ReserveBytes = 256u * 1024u * 1024u;
    const int ErrorAlreadyExists = 183;
    static readonly string LogPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "gpu_keepalive.log");
    static IntPtr mutex = IntPtr.Zero;

    // CUDA driver API. The memory calls must use their current (_v2) entry points: on some
    // drivers the old unsuffixed ones answer "invalid device context" even with a context set.
    [DllImport("nvcuda.dll")] static extern int cuInit(uint flags);
    [DllImport("nvcuda.dll")] static extern int cuDeviceGet(out int device, int ordinal);
    [DllImport("nvcuda.dll")] static extern int cuDevicePrimaryCtxRetain(out IntPtr context, int device);
    [DllImport("nvcuda.dll")] static extern int cuCtxSetCurrent(IntPtr context);
    [DllImport("nvcuda.dll", EntryPoint = "cuMemAlloc_v2")] static extern int cuMemAlloc(out ulong pointer, UIntPtr bytes);
    [DllImport("nvcuda.dll", EntryPoint = "cuMemsetD8_v2")] static extern int cuMemsetD8(ulong pointer, uint value, UIntPtr count);
    [DllImport("nvcuda.dll", EntryPoint = "cuMemGetInfo_v2")] static extern int cuMemGetInfo(out UIntPtr free, out UIntPtr total);
    [DllImport("nvcuda.dll")] static extern int cuGetErrorString(int code, out IntPtr text);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern IntPtr CreateMutexW(IntPtr attributes, bool initialOwner, string name);

    static string ErrorText(int code)
    {
        IntPtr text;
        cuGetErrorString(code, out text);
        return text == IntPtr.Zero ? "unknown error" : Marshal.PtrToStringAnsi(text);
    }

    static readonly UTF8Encoding Utf8NoBom = new UTF8Encoding(false);

    static void Log(string message)
    {
        try { File.AppendAllText(LogPath, DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") + " " + message + "\n", Utf8NoBom); }
        catch { }   // never let a logging problem stop the helper
    }

    // Create a context on the card and fill 256 MiB in it. Returns 0, or the CUDA error code.
    static int Hold(out IntPtr context, out ulong block)
    {
        context = IntPtr.Zero;
        block = 0;
        int device;
        int code = cuInit(0);
        if (code != 0) return code;
        code = cuDeviceGet(out device, 0);
        if (code != 0) return code;
        code = cuDevicePrimaryCtxRetain(out context, device);
        if (code != 0) return code;
        code = cuCtxSetCurrent(context);
        if (code != 0) return code;
        code = cuMemAlloc(out block, (UIntPtr)ReserveBytes);
        if (code != 0) return code;
        return cuMemsetD8(block, 0, (UIntPtr)ReserveBytes);
    }

    static void Main()
    {
        mutex = CreateMutexW(IntPtr.Zero, true, "Local\\GpuKeepAliveXid79");
        if (mutex == IntPtr.Zero || Marshal.GetLastWin32Error() == ErrorAlreadyExists) return;   // already running
        Log("started (pid " + Process.GetCurrentProcess().Id + ")");
        IntPtr context;
        ulong block;
        bool held = false;
        bool? wasOk = null;
        while (true)
        {
            if (!held)
            {
                int code = Hold(out context, out block);
                if (code == 0)
                {
                    held = true;
                    wasOk = true;
                    Log("holding a 256 MiB CUDA context on the card");
                }
                else
                {
                    if (wasOk != false) Log("card not available: " + code + " " + ErrorText(code));
                    wasOk = false;
                    Thread.Sleep(5000);
                    continue;
                }
            }
            Thread.Sleep(15000);
            UIntPtr free, total;
            int ping = cuMemGetInfo(out free, out total);
            bool ok = ping == 0;
            if (ok != wasOk)
            {
                // One line here is a crash on record: the moment the card stopped answering.
                Log(ok ? "card is answering again" : "CARD STOPPED ANSWERING: " + ping + " " + ErrorText(ping));
                wasOk = ok;
                if (!ok) held = false;   // rebuild the context once the card is back (after a restart)
            }
        }
    }
}
