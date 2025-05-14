#!/bin/env python3
import os

p = os.environ["PATH"]

for i in p.split(':'):
    print( f'* {i}')
