#!/usr/bin/env python3

map_authors = set([l.split(' = ')[0] for l in open('gcc.map').readlines()])

for author in [x.strip().split('\t')[1] for x in open('git-shortlog.txt').readlines()]:
    if not author in map_authors:
        print('Missing: ' + author)
