use std::io::{self, BufRead};

fn main() {
    let mut raw = Vec::new();
    let mut sorted = Vec::new();
    let stdin = io::stdin();

    for line in stdin.lock().lines() {
        let mut chars: Vec<char> = line.unwrap().chars().collect();
        let mut chars_sorted = chars.clone();
        raw.push(chars);
        chars_sorted.sort();
        sorted.push(chars_sorted);
    }

    part1(&sorted);
    part2(&raw);
}

fn part1(lines: &Vec<Vec<char>>) {
    let mut count2 = 0;
    let mut count3 = 0;
    for chars in lines {
        let mut last = '\u{0000}';
        let mut count = 0;
        let mut c2 = 0;
        let mut c3 = 0;
        for curr in chars {
            if last != *curr {
                last = *curr;
                count = 1;
                continue;
            }
            count += 1;
            if count == 2 {
                c2 += 1;
            }
            if count == 3 {
                c2 -= 1;
                c3 += 1;
            }
            if count == 4 {
                c3 -= 1;
            }
        }
        // println!("{} => {} {}", line, c2, c3);
        if c2 > 0 {
            count2 += 1;
        }
        if c3 > 0 {
            count3 += 1;
        }
    }
    println!("{} * {} = {}", count2, count3, count2 * count3);

}

fn part2(lines: &Vec<Vec<char>>) {
    for jpos in 0..lines.len() {
        for kpos in (jpos+1)..lines.len() {
            let mut diff = 0;
            let mut common: Vec<char> = Vec::new();
            for cpos in 0..lines[jpos].len() {
                if lines[jpos][cpos] == lines[kpos][cpos] {
                    common.push(lines[jpos][cpos]);
                    continue;
                }
                diff += 1;
                if diff > 1 {
                    break;
                }
            }
            // println!("{} {} {} {:?} {:?}", diff, jpos, kpos, lines[jpos], lines[kpos]);
            if diff > 1 {
                continue;
            }
            let common: String = common.into_iter().collect();
            // println!("=> {} {:?} {:?}", diff, lines[jpos], lines[kpos]);
            println!("{}", common);
        }
    }
}
