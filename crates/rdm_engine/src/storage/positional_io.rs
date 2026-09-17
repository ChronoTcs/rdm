use std::fs::File;
use std::io::Result;

/// Concurrent positional write without altering global file seek pointer.
pub fn write_at(file: &File, offset: u64, data: &[u8]) -> Result<usize> {
    #[cfg(target_os = "windows")]
    {
        use std::os::windows::fs::FileExt;
        file.seek_write(data, offset)
    }

    #[cfg(not(target_os = "windows"))]
    {
        use std::os::unix::fs::FileExt;
        file.write_all_at(data, offset)?;
        Ok(data.len())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::{Read, Seek, SeekFrom};
    use tempfile::NamedTempFile;

    #[test]
    fn test_positional_write() {
        let mut temp_file = NamedTempFile::new().unwrap();
        let file = temp_file.as_file_mut();

        let payload1 = b"HELLO_OFFSET_100";
        let payload2 = b"WORLD_OFFSET_200";

        write_at(file, 100, payload1).unwrap();
        write_at(file, 200, payload2).unwrap();

        let mut read_buf1 = vec![0u8; payload1.len()];
        let mut read_buf2 = vec![0u8; payload2.len()];

        file.seek(SeekFrom::Start(100)).unwrap();
        file.read_exact(&mut read_buf1).unwrap();
        assert_eq!(&read_buf1, payload1);

        file.seek(SeekFrom::Start(200)).unwrap();
        file.read_exact(&mut read_buf2).unwrap();
        assert_eq!(&read_buf2, payload2);
    }
}
