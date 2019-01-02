extern crate regex;

use std::io::{self, BufRead};
use std::collections::HashMap;
use regex::Regex;

fn main() {
    let lines = read_lines();
    let shifts = process_lines(&lines);
    shifts.analize();
}

fn read_lines() -> Vec<String> {
    let mut lines = Vec::new();
    let stdin = io::stdin();
    for line in stdin.lock().lines() {
        lines.push(line.unwrap());
    }
    lines.sort();
    lines
}

fn process_lines(lines: &Vec<String>) -> Shifts {
    let re = Regex::new(
        r#"(?x)
          ^
          \s*
          [\[]
          (?P<dy>\d{4})
          [-]
          (?P<dm>\d{2})
          [-]
          (?P<dd>\d{2})
          \s+
          (?P<th>\d{2})
          [:]
          (?P<tm>\d{2})
          [\]]
          \s+
          (Guard\ \#(?P<guard>[0-9]+)|(?P<sleeps>falls)|(?P<wakes>wakes))
          .*
          $
          "#).unwrap();

    let mut shifts = Shifts::new();
    for line in lines {
        let caps = re.captures(&line).unwrap();

        let dy = get_capture_as_i32(&caps, "dy".to_string());
        let dm = get_capture_as_i32(&caps, "dm".to_string());
        let dd = get_capture_as_i32(&caps, "dd".to_string());
        let mut date = Date::new_from_ymd(dy, dm, dd);

        let th = get_capture_as_i32(&caps, "th".to_string());
        let tm = get_capture_as_i32(&caps, "tm".to_string());

        let guard = get_capture_as_i32(&caps, "guard".to_string());
        if guard >= 0 {
            let mut day = date.get_julian();
            if th > 0 {
                // hour > 0 => it actually refers to PREVIOUS day (ex: 23:57)
                day += 1;
            }
            shifts.list.push(Shift::new(day, guard));
        }

        let sleeps = get_capture_as_bool(&caps, "sleeps".to_string());
        let wakes = get_capture_as_bool(&caps, "wakes".to_string());
        if sleeps && wakes {
            panic!("Guard cannot sleep and wake at the same time");
        }
        if sleeps || wakes {
            let pos = shifts.list.len()-1;
            let ref mut shift = shifts.list[pos];
            let mut s0 = date.get_stamp(th, tm);
            if s0 < shift.s0 {
                s0 = shift.s0;
            }
            for s in s0..shift.s1 {
                let k = (s - shift.s0) as usize;
                shift.asleep[k] = sleeps;
            }
        }
    }
    shifts
}

fn get_capture_as_i32(caps: &regex::Captures, name: String) -> i32 {
    match caps.name(&name) {
        Some(cap) => cap.as_str().parse::<i32>().unwrap(),
        None => -1,
    }
}

fn get_capture_as_bool(caps: &regex::Captures, name: String) -> bool {
    match caps.name(&name) {
        Some(_) => true,
        None => false,
    }
}

struct Shift {
    day: i32,
    guard: i32,
    asleep: [bool; 60],
    s0: i32,
    s1: i32,
}
impl Shift {
    fn new(day: i32, guard: i32) -> Shift {
        let mut date = Date::new_from_julian(day);
        Shift { day, guard, asleep: [false; 60],
                s0: date.get_stamp(0, 0), s1: date.get_stamp(1, 0) }
    }

    fn print(&self) {
        let mut date = Date::new_from_julian(self.day);
        let (_, m, d) = date.get_ymd();
        print!("{:02}-{:02} #{:5} ", m, d, self.guard);
        for s in 0..60 {
            print!("{}", if self.asleep[s] { "#" } else { "." });
        }
        println!("");
    }
}

struct Summary {
    guard: i32,
    minutes: i32,
    aslept: [i32; 60],
    max_pos: i32,
    max_aslept: i32,
}
impl Summary {
    fn new(guard: i32) -> Summary {
        Summary{ guard, minutes: 0, aslept: [0; 60], max_pos: -1, max_aslept: -1 }
    }
    fn consider(&mut self, pos: usize) {
        if self.max_aslept >= self.aslept[pos] {
            return;
        }
        self.max_aslept = self.aslept[pos];
        self.max_pos = pos as i32;
    }
    fn print(&self) {
        println!("{} => {} minutes, pos {} with {}", self.guard, self.minutes, self.max_pos, self.max_aslept);
    }
}

struct Winner {
    name: String,
    guard: i32,
    top: i32,
    pos: i32,
}
impl Winner {
    fn new(name: String) -> Winner {
        Winner{ name, guard: -1, top: -1, pos: -1 }
    }
    fn consider(&mut self, guard: i32, top: i32, pos: i32) {
        if self.top >= top {
            return;
        }
        self.top = top;
        self.guard = guard;
        self.pos = pos;
    }
    fn print(&self) {
        println!("GUARD {} {}: {} minutes, pos {} => {}", self.name, self.guard, self.top, self.pos, self.guard * self.pos);
    }
}

struct Shifts {
    list: Vec<Shift>,
}
impl Shifts {
    fn new() -> Shifts {
        Shifts { list: Vec::new() }
    }

    fn print(&self) {
        for shift in &self.list {
            shift.print();
        }
    }

    fn analize(&self) {
        self.print();

        let mut per_guard = HashMap::new();
        for shift in &self.list {
            let key = shift.guard;
            if !per_guard.contains_key(&key) {
                per_guard.insert(key, Summary::new(key));
            }
            let mut summary = per_guard.get_mut(&key).unwrap();
            for s in 0..60 {
                if !shift.asleep[s] {
                    continue;
                }
                summary.minutes += 1;
                summary.aslept[s] += 1;
            }
        }

        let mut minutes = Winner::new("minutes".to_string());
        let mut aslept = Winner::new("aslept".to_string());
        for (guard, mut summary) in per_guard {
            for s in 0..60 {
                summary.consider(s);
            }
            summary.print();

            minutes.consider(guard, summary.minutes, summary.max_pos);
            aslept.consider(guard, summary.max_aslept, summary.max_pos);
        }
        minutes.print();
        aslept.print();
    }
}

struct Date {
    y: i32,
    m: i32,
    d: i32,
    j: i32,
}
impl Date {
    const JULIAN_OFFSET: i32 = 2200000;

    fn new_from_ymd(y: i32, m: i32, d: i32) -> Date {
        Date { y, m, d, j: -1 }
    }
    fn new_from_julian(j: i32) -> Date {
        Date { j, y: -1, m: -1, d: -1 }
    }

    fn get_julian(&mut self) -> i32 {
        if self.j < 0 {
            let p: i32 = (self.m - 14) / 12;
            self.j = (1461 * (self.y + 4800 + p)) / 4 +
                          (367 * (self.m - 2 - 12 * p)) / 12 -
                          (3 * ((self.y + 4900 + p) / 100)) / 4 +
                          (self.d - 32075);
            self.j -= Date::JULIAN_OFFSET;
        }
        self.j
    }

    fn get_ymd(&mut self) -> (i32, i32, i32) {
        if self.y < 0 || self.m < 0 || self.d < 0 {
            let mut l = self.j + Date::JULIAN_OFFSET;
            l += 68569;
            let n = (4 * l) / 146097;
            l -= (146097 * n + 3) / 4;
            let i = (4000 * (l + 1)) / 1461001;
            l -= (1461 * i) / 4 - 31;
            let h = (80 * l) / 2447;
            let k = h / 11;
            self.d = l - (2447 * h) / 80;
            self.m = h + 2 - (12 * k);
            self.y = 100 * (n - 49) + i + k;
        }
        (self.y, self.m, self.d)
    }

    fn get_stamp(&mut self, h: i32, m: i32) -> i32 {
        (self.get_julian() * 24 + h) * 60 + m
    }
}
