use std::io::{self, BufRead};
use std::collections::HashMap;

const PREF_LENGTH: usize = 2;
const SUFF_LENGTH: usize = 2;
const PAD_LENGTH: i64 = PREF_LENGTH as i64 + SUFF_LENGTH as i64 + 1;
const POT_PLANT: char = '#';
const POT_EMPTY: char = '.';

#[derive(Debug)]
struct Rule {
    pattern: Vec<char>,
    outcome: char,
}
impl Rule {
    pub fn new(pattern: &str, outcome: &str) -> Rule {
        Rule{ pattern: pattern.to_string().chars().collect(), outcome: outcome.to_string().chars().next().unwrap() }
    }
}

#[derive(Debug)]
struct Data {
    initial: String,
    rules: Vec<Rule>,
}
impl Data {
    pub fn new() -> Data {
        Data{ initial: "".to_string(), rules: Vec::new() }
    }
    pub fn set_initial(&mut self, initial: &str) {
        self.initial = initial.to_string();
    }
    pub fn add_rule(&mut self, pattern: &str, outcome: &str) {
        self.rules.push(Rule::new(pattern, outcome));
    }
}

#[derive(Debug)]
struct Soil {
    iterations: usize,
    data: [Vec<char>; 2],
    cur: usize,
    beg: usize,
    end: usize,
    off: i64,
    seen: HashMap<String, (usize, i64)>,
}
impl Soil {
    fn set_pos(&mut self, which: usize, pos: usize, val: char) {
        if pos < self.data[which].len() {
            self.data[which][pos] = val;
        } else {
            self.data[which].push(val);
        }
    }
    pub fn new(initial: &str, iterations: usize) -> Soil {
        let data0 = Vec::new();
        let data1 = Vec::new();
        let seen = HashMap::new();
        let cur = 0;
        let mut soil = Soil{ data: [ data0, data1 ], cur, off: 0, beg: 0, end: 0, seen, iterations };

        let mut first = true;
        let mut pos = 0;
        for _p in 0..PAD_LENGTH {
            soil.set_pos(cur, pos, POT_EMPTY);
            pos += 1;
        }
        for _c in initial.chars() {
            let outcome = if _c == POT_EMPTY { POT_EMPTY } else { POT_PLANT };
            if outcome != POT_EMPTY  {
                if first {
                    soil.beg = pos;
                    first = false;
                }
                soil.end = pos + 1;
            }
            if !first || outcome != POT_EMPTY {
                soil.set_pos(cur, pos, outcome);
                pos += 1;
            }
        }
        for _p in 0..PAD_LENGTH {
            soil.set_pos(cur, pos, POT_EMPTY);
            pos += 1;
        }
        soil
    }
    pub fn step(&mut self, rules: &Vec<Rule>) {
        let nxt = 1 - self.cur;
        let mut first = true;
        let mut pos = 0;
        for _p in 0..PAD_LENGTH {
            self.set_pos(nxt, pos, POT_EMPTY);
            pos += 1;
        }
        for _p in (self.beg-PREF_LENGTH)..(self.end+SUFF_LENGTH) {
            let mut outcome = POT_EMPTY;
            for rule in rules {
                let mut matched = true;
                for _j in 0..rule.pattern.len() {
                    if rule.pattern[_j] != self.data[self.cur][_p+_j-PREF_LENGTH] {
                        matched = false;
                        break;
                    }
                }
                if matched {
                    outcome = rule.outcome;
                    break;
                }
            }
            if outcome != POT_EMPTY  {
                if first {
                    self.beg = pos;
                    self.off += _p as i64 - self.beg as i64;
                    first = false;
                }
                self.end = pos + 1;
            }
            if !first || outcome != POT_EMPTY {
                self.set_pos(nxt, pos, outcome);
                pos += 1;
            }
        }
        for _p in 0..PAD_LENGTH {
            self.set_pos(nxt, pos, POT_EMPTY);
            pos += 1;
        }
        self.cur = nxt;
    }
    pub fn done(&mut self, iter: usize) -> bool {
        let current: String = self.data[self.cur].iter().collect();
        match self.seen.get(&current) {
            Some(&(i, o)) => {
                let delta_iter = iter - i;
                let delta_off = self.off - o;
                println!("{}: SEEN iter {} off {} => {} {}", iter, i, o, delta_iter, delta_off);
                let remaining = self.iterations - iter;
                let final_offset: i64 = o as i64 + remaining as i64 * delta_off as i64;
                println!("REMAINING {} => {}", remaining, final_offset);
                self.off = final_offset;
                true
            },
            _ => {
                self.seen.insert(current, (iter, self.off));
                false
            },
        }
    }
}

fn main() {
    let data = read_data();
    run(&data, 20);
    run(&data, 50_000_000_000);
}

// 3503: WRONG (too low)
// 3798: RIGHT
//
// 3900000002290: WRONG (too high)
// 3900000002212: RIGHT
fn run(data: &Data, iterations: usize) {
    let mut soil = Soil::new(&data.initial, iterations);

    for iter in 0..iterations {
        soil.step(&data.rules);
        if soil.done(iter) {
            break;
        }
    }

    let mut total: i64 = 0;
    for pos in 0..soil.data[soil.cur].len() {
        if soil.data[soil.cur][pos] == POT_EMPTY {
            continue;
        }
        total += pos as i64 + soil.off - PAD_LENGTH;
    }
    println!("Sum of pots with plants after {} generations: {}", iterations, total);
}

fn read_data() -> Data {
    let mut data = Data::new();
    let stdin = io::stdin();
    for line in stdin.lock().lines() {
        let line = line.unwrap();
        let words: Vec<&str> = line.split_whitespace().collect();
        if words.len() < 3 {
            continue;
        }
        if words[0] == "initial" {
            data.set_initial(words[2]);
            continue;
        }
        data.add_rule(words[0], words[2]);
    }
    data
}
