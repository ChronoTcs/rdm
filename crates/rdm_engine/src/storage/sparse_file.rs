use std::fs::File;
use std::io::{Error, ErrorKind, Result};
use std::path::Path;

pub const FAT32_MAX_FILE_SIZE: u64 = 0xFFFF_FFFF; // 4 GB - 1 byte (4,294,967,295 bytes)

/// Checks if the target filesystem is FAT32.
/// On Windows, queries volume information; on Unix, checks statfs.
pub fn is_fat32_volume(path: &Path) -> bool {
    #[cfg(target_os = "windows")]
    {
        use std::os::windows::ffi::OsStrExt;
        use std::path::PathBuf;
        use std::ptr::null_mut;
        use windows_sys::Win32::Storage::FileSystem::GetVolumeInformationW;

        let root = match path.canonicalize() {
            Ok(canon) => canon
                .ancestors()
                .last()
                .map(|p| p.to_path_buf())
                .unwrap_or_else(|| PathBuf::from("C:\\")),
            Err(_) => PathBuf::from("C:\\"),
        };

        let mut wide_root: Vec<u16> = root.as_os_str().encode_wide().collect();
        if wide_root.is_empty() {
            return false;
        }
        if wide_root[wide_root.len() - 1] != 0 {
            if wide_root[wide_root.len() - 1] != (b'\\' as u16)
                && wide_root[wide_root.len() - 1] != (b'/' as u16)
            {
                wide_root.push(b'\\' as u16);
            }
            wide_root.push(0);
        }

        let mut fs_name = [0u16; 64];
        let ok = unsafe {
            GetVolumeInformationW(
                wide_root.as_ptr(),
                null_mut(),
                0,
                null_mut(),
                null_mut(),
                null_mut(),
                fs_name.as_mut_ptr(),
                fs_name.len() as u32,
            )
        };

        if ok != 0 {
            let fs_str = String::from_utf16_lossy(&fs_name);
            let clean = fs_str.trim_matches('\0').trim().to_uppercase();
            clean.contains("FAT") && !clean.contains("EXFAT")
        } else {
            false
        }
    }
    #[cfg(not(target_os = "windows"))]
    {
        false
    }
}

/// Pre-allocates a sparse file across Windows, Linux, and macOS without zero-filling stalls.
pub fn preallocate_sparse_file(
    file: &File,
    total_bytes: u64,
    target_path: &Path,
) -> Result<()> {
    // 1. FAT32 File Size Boundary Check
    if total_bytes >= FAT32_MAX_FILE_SIZE && is_fat32_volume(target_path) {
        return Err(Error::new(
            ErrorKind::FileTooLarge,
            "Target filesystem is FAT32 which cannot support files >= 4 GB. Choose an NTFS/exFAT/ext4 volume.",
        ));
    }

    #[cfg(target_os = "windows")]
    {
        use std::os::windows::io::AsRawHandle;
        use std::ptr::null_mut;
        use windows_sys::Win32::Storage::FileSystem::{
            FileAllocationInfo, SetEndOfFile, SetFileInformationByHandle, SetFilePointerEx,
            FILE_ALLOCATION_INFO, FILE_BEGIN,
        };
        use windows_sys::Win32::System::IO::DeviceIoControl;
        use windows_sys::Win32::System::Ioctl::FSCTL_SET_SPARSE;

        let handle = file.as_raw_handle() as windows_sys::Win32::Foundation::HANDLE;

        // Step A: Mark file as Sparse via DeviceIoControl
        let mut bytes_returned: u32 = 0;
        let sparse_res = unsafe {
            DeviceIoControl(
                handle,
                FSCTL_SET_SPARSE,
                null_mut(),
                0,
                null_mut(),
                0,
                &mut bytes_returned,
                null_mut(),
            )
        };

        if sparse_res != 0 {
            // NTFS Sparse mode succeeded: set logical allocation size instantly
            let mut alloc_info = FILE_ALLOCATION_INFO {
                AllocationSize: total_bytes as i64,
            };
            unsafe {
                SetFileInformationByHandle(
                    handle,
                    FileAllocationInfo,
                    &mut alloc_info as *mut _ as *mut std::ffi::c_void,
                    std::mem::size_of::<FILE_ALLOCATION_INFO>() as u32,
                );
            }
        } else {
            // Fallback for non-sparse filesystems (exFAT, FAT32, network drives)
            let mut new_pos: i64 = 0;
            unsafe {
                SetFilePointerEx(handle, total_bytes as i64, &mut new_pos, FILE_BEGIN);
                SetEndOfFile(handle);
                SetFilePointerEx(handle, 0, null_mut(), FILE_BEGIN);
            }
        }
    }

    #[cfg(target_os = "linux")]
    {
        use std::os::unix::io::AsRawFd;
        let fd = file.as_raw_fd();
        let ret = unsafe { libc::fallocate(fd, 0, 0, total_bytes as libc::off_t) };
        if ret != 0 {
            unsafe { libc::ftruncate(fd, total_bytes as libc::off_t) };
        }
    }

    #[cfg(target_os = "macos")]
    {
        use std::os::unix::io::AsRawFd;
        let fd = file.as_raw_fd();
        unsafe { libc::ftruncate(fd, total_bytes as libc::off_t) };
    }

    #[cfg(not(any(target_os = "windows", target_os = "linux", target_os = "macos")))]
    {
        file.set_len(total_bytes)?;
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::NamedTempFile;

    #[test]
    fn test_preallocate_file() {
        let temp_file = NamedTempFile::new().unwrap();
        let file = temp_file.as_file();
        let size = 10 * 1024 * 1024; // 10MB
        let res = preallocate_sparse_file(file, size, temp_file.path());
        assert!(res.is_ok());
    }
}
