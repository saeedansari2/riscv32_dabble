#!/usr/bin/env python3

import argparse

from pathlib import Path

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('--input', '-i')
    parser.add_argument('--output', '-o')
    args = parser.parse_args()

    datastore = {}
    min_addr = 1 << 64
    max_addr = 0
    with Path(args.input).open() as f:
        with Path(args.output).open('w') as fo:
            offset = 0
            for line in f:
                line = line.strip()
                if line == '':
                    continue
                count = int(line[1:3], 16)
                address = int(line[3:7], 16)
                rec_type = int(line[7:9], 16)
                data = line[9:-2]
                check = int(line[-2:], 16)
                if rec_type == 0:
                    for i in range(len(data) // 2):
                        min_addr = min(address + i + offset, min_addr)
                        max_addr = max(address + i + offset, max_addr)
                        datastore[address + i + offset] = int(data[i*2:(i+1)*2], 16)
                elif rec_type == 1:
                    # end of file
                    break
                elif rec_type == 2:
                    offset = int(data, 16) * 16
                elif rec_type == 4:
                    offset = int(data, 16) << 16
            min_addr &= ~0x3
            max_addr = (max_addr + 3) & ~0x3
            for i in range(min_addr, max_addr + 4, 4):
                val = ''
                for j in range(3, -1, -1):
                    if (i + j) in datastore:
                        val += f"{datastore[i + j]:02x}"
                    else:
                        val += "xx"
                if val != 'xxxxxxxx':
                    print(f"{i:06x}:{val}", file=fo)