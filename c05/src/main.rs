use std::io::{self, BufRead};

fn main() {
    let lines = read_lines();
    process_lines(&lines);
}

fn read_lines() -> Vec<String> {
    let mut lines = Vec::new();
    let stdin = io::stdin();
    for line in stdin.lock().lines() {
        lines.push(line.unwrap());
    }
    lines
}

fn process_lines(lines: &Vec<String>) {
    part1(lines);
    part2(lines);
}

fn part1(lines: &Vec<String>) {
    for line in lines {
        let vec = line.as_bytes().to_vec();
        let len_orig = vec.len();
        let len_reacted = react(&vec);
        println!("{} => {}", len_orig, len_reacted);
    }
}

fn part2(lines: &Vec<String>) {
    let mut min_unit = ' ' as u8;
    let mut min_len = std::usize::MAX;
    for line in lines {
        let bytes = line.as_bytes();
        let (beg, end) = limits(bytes);
        println!("Scanning from {} to {}", beg as char, end as char);
        for unit in beg..end+1 { // interval is [beg, end)
            let mut vec = bytes.to_vec();
            remove_unit(unit, &mut vec);
            let len_orig = vec.len();
            let len_reacted = react(&vec);
            println!("{}: {} => {}", unit as char, len_orig, len_reacted);
            if min_len > len_reacted {
                min_len = len_reacted;
                min_unit = unit;
            }
        }
        println!("MIN {} {}", min_unit as char, min_len);
    }
}

fn react(polymer: &Vec<u8>) -> usize {
    let mut collapsed = polymer.clone();
    let mut pos;
    loop {
        pos = 0;
        let mut prev: u8 = 0;
        for j in 0..collapsed.len() {
            let curr = collapsed[j];
            let cl = curr.to_ascii_lowercase();
            let pl = prev.to_ascii_lowercase();
            if prev != curr && pl == cl {
                prev = 0;
                continue;
            }
            if prev != 0 {
                collapsed[pos] = prev;
                pos += 1;
            }
            prev = curr;
        }
        if prev != 0 {
            collapsed[pos] = prev;
            pos += 1;
        }
        // println!("{}", current.len());
        if pos == collapsed.len() {
            break;
        }
        collapsed.truncate(pos);
    }
    pos
}

fn remove_unit(unit: u8, polymer: &mut Vec<u8>) {
    let mut pos = 0;
    let upp = unit.to_ascii_uppercase();
    let low = unit.to_ascii_lowercase();
    for j in 0..polymer.len() {
        let curr = polymer[j];
        if curr == upp || curr == low {
            continue;
        }
        polymer[pos] = curr;
        pos += 1;
    }
    polymer.truncate(pos);
}

fn limits(bytes: &[u8]) -> (u8, u8) {
    let mut beg:u8 = 0;
    let mut end:u8 = 0;
    for byte in bytes {
        let low = byte.to_ascii_lowercase();
        if beg == 0 || beg > low {
            beg = low;
        }
        if end == 0 || end < low {
            end = low;
        }
    }
    (beg, end)
}
