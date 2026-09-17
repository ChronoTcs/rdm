use super::positional_io::write_at;
use std::fs::File;
use std::io::Result;
use std::time::Instant;

pub const COALESCE_BUFFER_SIZE: usize = 1024 * 1024; // 1 MB buffer ring
pub const FLUSH_TIMEOUT_MS: u128 = 250; // 250ms timer threshold

pub struct WriteCoalescer {
    buffer: Vec<u8>,
    base_offset: u64,
    last_flush: Instant,
}

impl WriteCoalescer {
    pub fn new(initial_offset: u64) -> Self {
        Self {
            buffer: Vec::with_capacity(COALESCE_BUFFER_SIZE),
            base_offset: initial_offset,
            last_flush: Instant::now(),
        }
    }

    pub fn append_and_maybe_flush(
        &mut self,
        file: &File,
        offset: u64,
        data: &[u8],
    ) -> Result<usize> {
        // If data is discontinuous from base_offset + buffer.len, flush current buffer first
        if offset != self.base_offset + self.buffer.len() as u64 && !self.buffer.is_empty() {
            self.flush(file)?;
            self.base_offset = offset;
        }

        self.buffer.extend_from_slice(data);

        // Check flush triggers: buffer full (1MB) or timeout elapsed (250ms)
        if self.buffer.len() >= COALESCE_BUFFER_SIZE
            || self.last_flush.elapsed().as_millis() >= FLUSH_TIMEOUT_MS
        {
            self.flush(file)?;
        }

        Ok(data.len())
    }

    pub fn flush(&mut self, file: &File) -> Result<()> {
        if self.buffer.is_empty() {
            return Ok(());
        }

        write_at(file, self.base_offset, &self.buffer)?;
        self.base_offset += self.buffer.len() as u64;
        self.buffer.clear();
        self.last_flush = Instant::now();
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::{Read, Seek, SeekFrom};
    use tempfile::NamedTempFile;

    #[test]
    fn test_write_coalescer() {
        let mut temp_file = NamedTempFile::new().unwrap();
        let file = temp_file.as_file_mut();

        let mut coalescer = WriteCoalescer::new(0);
        let chunk = vec![65u8; 1024]; // 1KB 'A'
        coalescer.append_and_maybe_flush(file, 0, &chunk).unwrap();
        coalescer.append_and_maybe_flush(file, 1024, &chunk).unwrap();
        coalescer.flush(file).unwrap();

        let mut read_buf = vec![0u8; 2048];
        file.seek(SeekFrom::Start(0)).unwrap();
        file.read_exact(&mut read_buf).unwrap();
        assert_eq!(read_buf[0], 65);
        assert_eq!(read_buf[2047], 65);
    }
}
