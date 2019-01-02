extern crate regex;

use std::io::{self, BufRead};
use std::collections::HashMap;
use regex::Regex;

// const MIN_DELAY: i32 = 0;
// const NUM_WORKERS: usize = 2;

const MIN_DELAY: i32 = 60;
const NUM_WORKERS: usize = 5;

fn main() {
    let lines = read_lines();
    let mut graph = process_lines(lines);
    println!("graph {:?}", graph);
    part1(&graph); // BFLNGIRUSJXEHKQPVTYOCZDWMA
    part2(&mut graph); // 880
}

fn part1(graph: &Graph) {
    let sorted = graph.topological_sort();
    println!("sorted {:?}", sorted);
}

#[derive(Copy, Clone)]
#[derive(Debug)]
struct Unit {
    node: usize,
    pending: i32,
}

fn part2(graph: &mut Graph) {
    let mut workers = vec![Unit{node: 0, pending: 0}; NUM_WORKERS];
    let mut total_elapsed = 0;
    loop {
        let degree = graph.build_degree();

        // get all nodes that are ready to be processed, sorted
        let mut zeros: Vec<_> = degree
            .iter()
            .filter(|&(_, &v)| v == 0)
            .map(|(k, _)| *k)
            .collect();
        zeros.sort_by(|a, b| { graph.nodes[*a].cmp(&graph.nodes[*b]) });
        println!("zeros: {}", zeros.iter().map(|x| graph.nodes[*x].clone()).collect::<Vec<_>>().join(","));

        // get active workers
        let mut active = HashMap::new();
        let mut min_pending = std::i32::MAX;
        for worker in &mut workers {
            if worker.pending == 0 {
                continue;
            }

            active.insert(worker.node, 1);
            if min_pending > worker.pending {
                min_pending = worker.pending;
            }
        }

        // assign unassigned zeros to free workers
        for zero in zeros {
            if active.contains_key(&zero) {
                println!("skipping zero in progress {}", graph.nodes[zero]);
                continue;
            }

            let mut assigned = false;
            for worker in &mut workers {
                if worker.pending > 0 {
                    continue;
                }
                worker.node = zero;
                worker.pending = node_time(&graph.nodes[zero]);
                println!("assigned node {} => {}", graph.nodes[zero], worker.pending);
                assigned = true;

                active.insert(worker.node, 1);
                if min_pending > worker.pending {
                    min_pending = worker.pending;
                }
                break;
            }
            if !assigned {
                // no available workers, don't waste time
                println!("no available workers for now");
                break;
            }
        }
        if active.is_empty() {
            // no active workers, we must be done!
            println!("no active workers, done");
            break;
        }

        // now "wait" the min pending time
        for worker in &mut workers {
            if worker.pending == 0 {
                continue;
            }
            worker.pending -= min_pending;
            if worker.pending == 0 {
                // node finished, remove it
                println!("node {} done", graph.nodes[worker.node]);
                graph.del_node(worker.node);
            }
        }
        total_elapsed += min_pending;
    }
    println!("total elapsed {}", total_elapsed);
}

fn node_time(node: &String) -> i32 {
    let mut time = MIN_DELAY;
    for byte in node.chars() {
        time += (byte as i32) - ('A' as i32) + (1 as i32);
    }
    time
}

fn read_lines() -> Vec<(String, String)> {
    let re = Regex::new(
        r#"(?x)
          ^
          \s*
          Step
          \s+
          (?P<before>[-_a-zA-Z0-9]+)  # step before
          \s+
          must\ be\ finished\ before\ step
          \s+
          (?P<after>[-_a-zA-Z0-9]+)  # step after
          \s+
          can\ begin\.
          \s*
          $
          "#).unwrap();
    let mut lines = Vec::new();
    let stdin = io::stdin();
    for line in stdin.lock().lines() {
        let line = line.unwrap();
        let caps = re.captures(&line).unwrap();
        let before = get_capture_as_string(&caps, "before".to_string());
        let after = get_capture_as_string(&caps, "after".to_string());
        lines.push((before, after));
    }
    lines
}

fn process_lines(lines: Vec<(String, String)>) -> Graph {
    let mut graph = Graph::new();
    for line in lines {
        graph.add_edge(line.0, line.1);
    }
    graph
}

#[derive(Debug)]
struct Graph {
    nodes: Vec<String>,
    names: HashMap<String, usize>,
    neighbors: HashMap<usize, Vec<usize>>,
}
impl Graph {
    pub fn new() -> Graph {
        Graph{ nodes: Vec::new(), names: HashMap::new(),  neighbors: HashMap::new() }
    }
    pub fn add_node(&mut self, name: String) -> usize {
        let mut pos = self.nodes.len();
        if self.names.contains_key(&name) {
            pos = *self.names.get(&name).unwrap();
        } else {
            self.names.insert(name.clone(), pos);
            self.nodes.push(name.clone());
        }
        pos
    }
    pub fn del_node(&mut self, pos: usize) {
        self.names.remove(&self.nodes[pos]);
        // self.nodes.remove(pos);
        self.neighbors.remove(&pos);
        // println!("After removing {}, neighbors is {:?}", pos, self.neighbors);
    }
    pub fn add_edge(&mut self, before: String, after: String) {
        let pb = self.add_node(before);
        let pa = self.add_node(after);
        let neighbor = self.neighbors.entry(pb).or_insert(Vec::new());
        neighbor.push(pa);
    }
    pub fn build_degree(&self) -> HashMap<usize, u32> {
        let mut degree = HashMap::new();
        for node in &self.nodes {
            if !self.names.contains_key(node) {
                continue;
            }
            let parent = self.names.get(node).unwrap();
            degree.entry(*parent).or_insert(0);
            if !self.neighbors.contains_key(parent) {
                continue;
            }
            for child in self.neighbors.get(parent).unwrap() {
                let mut after = degree.entry(*child).or_insert(0);
                *after += 1;
            }
        }
        degree
    }
    pub fn topological_sort(&self) -> String {
        let mut degree = self.build_degree();
        let mut queue: Vec<usize> = Vec::new();
        let mut nodes: Vec<usize> = Vec::new();
        loop {
            let zeros: Vec<_> = degree
                .iter()
                .filter(|&(_, &v)| v == 0)
                .map(|(k, _)| *k)
                .collect();
            queue.append(&mut zeros.clone());
            for zero in zeros { degree.remove(&zero); }
            // println!("queue: {:?}", queue);
            if queue.is_empty() {
                break;
            }
            queue.sort_by(|a, b| { self.nodes[*a].cmp(&self.nodes[*b]) });
            let node = queue.remove(0);
            match self.neighbors.get(&node) {
                Some(neighbors) => {
                    for neighbor in neighbors {
                        let mut after = degree.get_mut(neighbor).unwrap();
                        *after -= 1;
                    }
                }
                None => { }
            }
            nodes.push(node);
        }
        nodes.iter().map(|x| self.nodes[*x].clone()).collect::<Vec<_>>().join("")
    }
}

fn get_capture_as_string(caps: &regex::Captures, name: String) -> String {
    match caps.name(&name) {
        Some(cap) => cap.as_str().to_string(),
        None => "".to_string(),
    }
}
