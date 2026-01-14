const std = @import("std");
const builtin = @import("builtin");

const options = @import("options");

/// Received an error code that doesn't have a mapped enum value,
/// which could be possible in a variety of ways: Windy handling memory
/// incorrectly, later XCB versions introducing new values that Windy
/// doesn't cover yet, etc.
pub const XcbUnknownError = error{Unknown};

/// Generic flush error, as the error codes (if any) seem to be undocumented,
/// the docs just claim that a negative return value is an error.
pub const XcbFlushError = error{Flush};

pub const XcbConnectionError = error{
    /// `XCB_CONN_ERROR`: Socket, pipe and other stream errors.
    Connection,
    /// `XCB_CONN_CLOSED_EXT_NOTSUPPORTED`: An extension is not supported.
    ExtUnsupported,
    /// `XCB_CONN_CLOSED_MEM_INSUFFICIENT`: Either `malloc()`, `calloc()` or `realloc()` failed.
    OutOfMemory,
    /// `XCB_CONN_CLOSED_REQ_LEN_EXCEED`: Exceeded the request length that the server accepts.
    ReqLenExceed,
    /// `XCB_CONN_CLOSED_PARSE_ERR`: Failed to parse the display string.
    Parse,
    /// `XCB_CONN_CLOSED_INVALID_SCREEN`: The server does not have a screen that matches the display.
    InvalidScreen,
    /// `XCB_CONN_CLOSED_FDPASSING_FAILED`: Failed to pass a file descriptor.
    FdPass,
} || XcbUnknownError;

/// These refer to the type of the error struct that we received, e.g.: `xcb_request_error_t`.
pub const XcbGenericError = error{
    Request,
    Value,
    Window,
    Pixmap,
    Atom,
    Cursor,
    Font,
    Match,
    Drawable,
    Access,
    OutOfMemory,
    Colormap,
    GraphicsContext,
    IdChoice,
    Name,
    Length,
    Implementation,
} || XcbUnknownError;

/// These refer to errors within keymap creation/update.
pub const XcbKeymapError = error{
    Keymap,
    KeyState,
};

/// These refer to all sorts of initialization errors, such as
/// the screen or the keyboard missing, XKB setup failing, etc.
pub const XcbInitError = error{
    /// Could not find the screen that the XCB connection claimed to exist.
    NoScreen,
    /// Could not find the XKB device ID of the core keyboard.
    NoCoreKeyboard,
    /// Setting up XKB failed.
    XkbSetup,
    /// Acquiring a XKB context failed.
    XkbContext,
    /// Ran out of memory trying to get an atom.
    OutOfMemory,
} || XcbConnectionError || XcbGenericError || XcbKeymapError;

pub const XcbFlushedCallError = XcbGenericError || XcbFlushError;

pub const XcbEventError = error{
    /// Could not find the window attached to the received event
    /// in the internal window map.
    WindowMissing,
    /// Received a null reply for a selection chunk.
    Selection,
    /// Ran out of memory in the clipboard buffer.
    OutOfMemory,
} || XcbFlushedCallError || XcbKeymapError;

pub const XcbSetClipboardError = XcbEventError || XcbFlushedCallError;
pub const XcbGetClipboardError = error{OutOfMemory} || XcbFlushedCallError || XcbEventError;
pub const XcbCreateWindowError = XcbSetTitleError || XcbFlushedCallError;
pub const XcbClipboardWindowError = XcbFlushedCallError;
pub const XcbCreateCursorError = XcbGenericError;
pub const XcbSetTitleError = error{OutOfMemory} || XcbFlushedCallError;
pub const XcbSetCursorError = XcbFlushedCallError;
pub const XcbEventRegisterError = XcbFlushedCallError;
pub const XcbNormalHintError = XcbFlushedCallError;
pub const XcbResizeError = XcbFlushedCallError;
pub const XcbMoveError = XcbFlushedCallError;

pub const WinInitError = error{
    /// Initializing COM failed.
    ///
    /// A more fine-grained error code is logged using `std.log.err`.
    ComInit,
    /// Could not retrieve the base Win32 instance.
    ///
    /// A more fine-grained error code is logged using `std.log.err`.
    Instance,
    /// Could not find either `WINDY_ICON` in the attached resource file,
    /// or Win32's `IDI_APPLICATION`.
    ///
    /// A more fine-grained error code is logged using `std.log.err`.
    WindowIcon,
    /// Creating the main window class (used for window creation) failed.
    ///
    /// A more fine-grained error code is logged using `std.log.err`.
    MainClass,
    /// Creating the clipboard window class failed.
    ///
    /// A more fine-grained error code is logged using `std.log.err`.
    ClipboardClass,
};

pub const WinIconError = error{
    /// Could not find a device context: `GetDC()` returned null.
    ///
    /// A more fine-grained error code is logged using `std.log.err`.
    DeviceContext,
    /// Could not find a DIB section: `CreateDIBSection()` returned null.
    ///
    /// A more fine-grained error code is logged using `std.log.err`.
    DibSection,
    /// Could not create the mask bitmap: `CreateBitmap()` returned null.
    ///
    /// A more fine-grained error code is logged using `std.log.err`.
    IconMask,
    /// Could not create the icon: `CreateIconIndirect()` returned null.
    ///
    /// A more fine-grained error code is logged using `std.log.err`.
    IconCreate,
};

/// The errors returned by `std.unicode` functions.
pub const WinConversionError = error{ OutOfMemory, InvalidWtf8 };

/// Errors are currently handled in a callback, so they return no errors.
/// In the future they might be able to dispatch errors to a specified
/// callback, or they might be processed inline, optionally.
pub const WinEventError = error{};

pub const WinSetClipboardError = error{
    /// The clipboard is currently in use by another program
    /// and was locked during the 5x2 ms spent in internal retries.
    ///
    /// Further calls might succeed, as the clipboard might lose its lock.
    ClipboardLocked,
    /// Setting the clipboard with the given data failed.
    ///
    /// A more fine-grained error code is logged using `std.log.err`.
    ClipboardSet,
    /// Locking the clipboard memory failed.
    ///
    /// A more fine-grained error code is logged using `std.log.err`.
    MemoryLock,
} || WinConversionError;

pub const WinGetClipboardError = error{
    /// The clipboard is currently in use by another program
    /// and was locked during the 5x2 ms spent in internal retries.
    ///
    /// Further calls might succeed, as the clipboard might lose its lock.
    ClipboardLocked,
    /// Acquiring the clipboard memory failed.
    ///
    /// A more fine-grained error code is logged using `std.log.err`.
    ClipboardGet,
    /// Locking the clipboard memory failed.
    ///
    /// A more fine-grained error code is logged using `std.log.err`.
    MemoryLock,
} || WinConversionError;

pub const WinCreateWindowError = error{
    /// Creating the window failed.
    ///
    /// A more fine-grained error code is logged using `std.log.err`.
    CreateWindow,
} || WinConversionError;

pub const WinClipboardWindowError = error{
    /// Creating the window failed.
    ///
    /// A more fine-grained error code is logged using `std.log.err`.
    CreateWindow,
};

pub const WinCreateCursorError = WinIconError;
pub const WinSetTitleError = WinConversionError;
pub const WinSetCursorError = error{};
pub const WinNormalHintError = error{};
pub const WinResizeError = error{};
pub const WinMoveError = error{};

/// This is an union of all the platform-specific errors,
/// but you can discard certain platforms' errors if you do not support them,
/// each platform is guaranteed to return errors from their own error set.
pub const InitError = XcbInitError || XcbClipboardWindowError ||
    WinInitError || WinClipboardWindowError;

/// This is an union of all the platform-specific errors,
/// but you can discard certain platforms' errors if you do not support them,
/// each platform is guaranteed to return errors from their own error set.
pub const EventError = XcbEventError || WinEventError;

/// This is an union of all the platform-specific errors,
/// but you can discard certain platforms' errors if you do not support them,
/// each platform is guaranteed to return errors from their own error set.
pub const SetClipboardError = XcbSetClipboardError || WinSetClipboardError;

/// This is an union of all the platform-specific errors,
/// but you can discard certain platforms' errors if you do not support them,
/// each platform is guaranteed to return errors from their own error set.
pub const GetClipboardError = XcbGetClipboardError || WinGetClipboardError;

/// This is an union of all the platform-specific errors,
/// but you can discard certain platforms' errors if you do not support them,
/// each platform is guaranteed to return errors from their own error set.
pub const CreateWindowError = XcbCreateWindowError || WinCreateWindowError;

/// This is an union of all the platform-specific errors,
/// but you can discard certain platforms' errors if you do not support them,
/// each platform is guaranteed to return errors from their own error set.
pub const CreateCursorError = XcbCreateCursorError || WinCreateCursorError;

/// This is an union of all the platform-specific errors,
/// but you can discard certain platforms' errors if you do not support them,
/// each platform is guaranteed to return errors from their own error set.
pub const SetTitleError = XcbSetTitleError || WinSetTitleError;

/// This is an union of all the platform-specific errors,
/// but you can discard certain platforms' errors if you do not support them,
/// each platform is guaranteed to return errors from their own error set.
pub const SetCursorError = XcbSetCursorError || WinSetCursorError;

/// This is an union of all the platform-specific errors,
/// but you can discard certain platforms' errors if you do not support them,
/// each platform is guaranteed to return errors from their own error set.
pub const EventRegisterError = XcbEventRegisterError;

/// This is an union of all the platform-specific errors,
/// but you can discard certain platforms' errors if you do not support them,
/// each platform is guaranteed to return errors from their own error set.
pub const NormalHintError = XcbNormalHintError || WinNormalHintError;

/// This is an union of all the platform-specific errors,
/// but you can discard certain platforms' errors if you do not support them,
/// each platform is guaranteed to return errors from their own error set.
pub const ResizeError = XcbResizeError || WinResizeError;

/// This is an union of all the platform-specific errors,
/// but you can discard certain platforms' errors if you do not support them,
/// each platform is guaranteed to return errors from their own error set.
pub const MoveError = XcbMoveError || WinMoveError;
