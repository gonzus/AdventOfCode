use std::io::{self, BufRead};
use std::collections::HashMap;

#[derive(Debug)]
struct Info {
    count: usize,
    sum: usize,
    memory: HashMap<usize, usize>,
}
impl Info {
    pub fn new() -> Info {
        Info{ count: 0, sum: 0, memory: HashMap::new() }
    }
}

fn main() {
    let words = read_words();
    // println!("words {:?}", words);
    let mut info = Info::new();
    parse_words(&words, 0, &mut info);
    println!("sum metas {:?}", info.sum);
    println!("value for root {:?}", info.memory.get(&0).unwrap());
}

fn read_words() -> Vec<usize> {
    let mut words = Vec::new();
    let stdin = io::stdin();
    for line in stdin.lock().lines() {
        let line = line.unwrap();
        for word in line.split_whitespace() {
            words.push(word.to_string().parse::<usize>().unwrap());
        }
    }
    words
}

fn parse_words(words: &Vec<usize>, pos: usize, info: &mut Info) -> usize {
    let name = info.count;
    info.count += 1;

    let count_c = words[pos];
    let count_m = words[pos+1];
    // println!("node {}: {} children, {} metas", name, count_c, count_m);
    let mut delta = 2;

    let mut children: HashMap<usize, usize> = HashMap::new();
    for child in 0..count_c {
        children.insert(child, info.count);
        // println!("  node {}, child #{} is {}", name, child, info.count);
        let x = pos + delta;
        delta += parse_words(words, x, info);
    }
    let mut metas: Vec<usize> = Vec::new();
    let mut sum = 0;
    for _meta in 0..count_m {
        let x = pos + delta;
        // println!("meta {}", words[x]);
        delta += 1;
        sum += words[x];
        metas.push(words[x] - 1);
    }
    info.sum += sum;

    let mut data = 0;
    if count_c == 0 {
        // println!("  node {}, no children, value {}", name, sum);
        data += sum;
    } else {
        for meta in metas {
            let child = children.entry(meta).or_insert(0);
            let value = info.memory.entry(*child).or_insert(0);
            // println!("  node {}: meta {} is child {} value {}", name, meta, *child, value);
            data += *value;
        }
    }
    info.memory.insert(name, data);
    return delta;
}
