import sys # for sys.argv, sys.exit()

from intelhex import IntelHex

HEX2TAPE_LGP30_VERSION = 1.0

BITS_PER_HEX = 4
HEX_MASK = 0xF
HEX_PER_WORD = 8 # 32 / BITS_PER_HEX
BYTES_PER_HEX_RECORD = 16 # on output to the hex file
LGP30_WORD_MASK = 0xffffffff # 32 bits
MAX_CHUNK_SIZE = 64
MAX_LINE_SIZE = 8

# Indices for (address,value) tuples
ADDR_INDEX = 0
VAL_INDEX = 1

# testing purposes only
def make_segment(mem, start_address, size):
    for i in range(size):
        mem[start_address + i] = start_address + i

# testing purposes only (a replacement for hexfile_to_mem)
def make_test(mem):
    make_segment(mem, 7, 1)         # a very short segment
    make_segment(mem,11, 64)        # a segment with exactly 64 words (MAX_CHUNK_SIZE) / 1 chunk
    make_segment(mem, 101, 65)      # a segment just over 1 chunk in size
    make_segment(mem, 2043, 128)    # a segment exactly 2 chunks in size
    make_segment(mem, 400, 133)     # a segment over two chunk s in size
    return 999                      # start address

def value2sex(value):
    # No need for lobal constants
    WORD_MASK = 0xffffffff
    SEX_DIGITS_PER_GROUP = 8
    BITS_PER_DIGIT = 4
    DIGIT_MASK = 15
    SEX_CHARSET = {
        0: '0', 
        1: '1',
        2: '2',
        3: '3',
        4: '4',
        5: '5',
        6: '6',
        7: '7',
        8: '8', 
        9: '9',
        10: 'f',
        11: 'g',
        12: 'j', 
        13: 'k', 
        14: 'q',
        15: 'w'
        }   
    _value = value & WORD_MASK # limit to 8 digits
    sex = ''
    for i in range(SEX_DIGITS_PER_GROUP):
        digit_value = _value & DIGIT_MASK
        _value = _value >> BITS_PER_DIGIT
        digit_char = SEX_CHARSET[digit_value]
        sex = digit_char + sex
    return sex

def address2base64(address):
    SECTORS_PER_TRACK = 64
    (track_part, sector_part) = divmod(address, SECTORS_PER_TRACK)
    return(f"{value2sex(track_part)[-2:]}{value2sex(sector_part)[-2:]}")

def hexfile_to_mem(hexfile, mem):
        # No validation done here. Assumed:
        # The hexfile exists
        # The hexfile contains a valid memory image
        # The hexfile contains a valid LGP-30 start address in IP, with CS = 0
        
        ih = IntelHex()
        
        try:
            ih.loadhex(hexfile)
        except:
            print(f"Drum: Intel hex file {hexfile} - load failed")
            raise

        for (start_addr, end_addr) in ih.segments():
            print(f"Drum: Segment byte range: {start_addr} - {end_addr}")
            # start is inclusive, end is exclusive
            # check for LGP-30 word boundaries
            if start_addr % HEX_PER_WORD == 0 and end_addr % HEX_PER_WORD == 0:
                byte_addr = start_addr
                # spin through the bytes in groups of HEX_PER_WORD
                while byte_addr < end_addr:
                    mem_word = 0
                    word_addr = byte_addr // HEX_PER_WORD
                    for _ in range(HEX_PER_WORD):
                        mem_word = (mem_word << BITS_PER_HEX) + ih[byte_addr]
                        byte_addr += 1
                    if mem_word & (~LGP30_WORD_MASK):
                        print(f"Warning: Word length exceeds 32 bits at address {word_addr}")
                    if mem_word & 1 != 0:
                        print(f"Warning: Non-zero LSB at address {word_addr}")
                    mem[word_addr] = mem_word
                    print(f"Address: {word_addr} <-- {mem[word_addr]}")
            else:
                print(f"Drum: Intel hex file {hexfile} - segment not word-aligned")
                return None
        try:
            program_seg = ih.start_addr['CS']
            program_start = ih.start_addr['IP']
        except:
            print(f"Drum: Intel hex file {hexfile} - bad start address")
            raise
            
        if program_seg != 0:
            print(f"Drum: Intel hex file {hexfile} - bad start address (non-zero CS)")
            raise ValueError()
        else:    
            print(f"Drum: Program start address: {program_start}")
            return program_start

def hexname_to_tapename(hexname):
    return hexname + ".lgp30_tape"

def splitify(mem):
    # split mem into contiguous segments
    # sort mem in place with ascending addresses (as a list)
    sorted_mem = sorted(mem.items(), key=lambda item: item[0])
    segments = []
    new_segment = [sorted_mem[0]]
    for index in range(1,len(sorted_mem)):
        if sorted_mem[index][ADDR_INDEX] - sorted_mem[index-1][ADDR_INDEX] == 1:
            new_segment.append(sorted_mem[index])
        else:
            segments.append(new_segment)
            new_segment = [sorted_mem[index]]
    segments.append(new_segment)
    return segments

def chunkify(segment):
    # split segment into chunks of MAX_CHUNK_SIZE words or less
    chunks = []
    new_chunk = [segment[0]]
    for index in range(1, len(segment)):
        if len(new_chunk) < MAX_CHUNK_SIZE:
            new_chunk.append(segment[index])
        else:
            chunks.append(new_chunk)
            new_chunk = [segment[index]]
    chunks.append(new_chunk)
    return chunks

def output_v_header(file, chunk):
    chunk_size = len(chunk) # up to MAX_CHUNK_SIZE
    chunk_addr = chunk[0][ADDR_INDEX] # address part of first tuple in chunk
    v_header = f"v{value2sex(chunk_size)[-3:]}{address2base64(chunk_addr)}'"
    print(v_header, file = file)

def output_chunk(file, chunk):
    # output chunk in lines of MAX_LINE_SIZE words or less
    counter = 0
    for index in range(len(chunk)):
        if counter < MAX_LINE_SIZE:
            print(f"{value2sex(chunk[index][VAL_INDEX])}'", end='', file = file)
            counter += 1
        else:
            print(file = file) 
            print(f"{value2sex(chunk[index][VAL_INDEX])}'", end='', file = file)
            counter = 1
    print(file = file)

def output_start_header(file, start_addr):
    print(f".000{address2base64(start_addr)}'", file = file)

def mem_to_tapefile(memory, start_addr, hexfile):
    tape_file = hexname_to_tapename(hexfile)
    with open(tape_file, encoding='utf-8', mode='w') as tapefile:
        segments = splitify(memory)
        for segment in segments:
            # split each segment into chunks
            chunks = chunkify(segment)
            for chunk in chunks:
                # output each chunk
                output_v_header(tapefile, chunk)
                output_chunk(tapefile, chunk)
        output_start_header(tapefile, start_addr)

def main():
    print(f"HEX2TAPE_LGP30 version {HEX2TAPE_LGP30_VERSION}")
    memory = {}
    if len(sys.argv) != 2:
        print('Error - Incorrect argument count')
        print('Usage: hex2tape <intelhex_file_name>')
        sys.exit(1)
    try:
        # start_address = make_test(memory)
        start_address = hexfile_to_mem(sys.argv[1], memory)
    except:
        sys.exit(1)
    try:
        mem_to_tapefile(memory, start_address, sys.argv[1])
    except:
        sys.exit(1)

if __name__ == "__main__":
    main()
    sys.exit(0)
