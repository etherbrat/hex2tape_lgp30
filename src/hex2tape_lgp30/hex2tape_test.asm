; a test file for the hex2tape program
;
.locn 7 ; any old address
.blkw 1 ; a very short segment

.locn 11 ; any old address
.blkw 64 ; a segment with exactly 64 words (MAX_CHUNK_SIZE) / 1 chunk

.locn 101 ; any old address
.blkw 65 ; a segment just over 1 chunk in size

.locn 203 ; any old address
.blkw 128 ; a segement of exactly 2 chunks in size

.locn 400 ; any oldl address
.blkw 133  ; a segment of over two chunks in size

.end 999
