#!/usr/bin/python
import pyphen
import sys

def syllabes(word):
    #referred from stackoverflow.com/questions/14541303/count-the-number-of-syllables-in-a-word
    count = 0
    vowels = 'aeiouy'
    word = word.lower()
    if word[0] in vowels:
        count +=1
    for index in range(1,len(word)):
        if word[index] in vowels and word[index-1] not in vowels:
            count +=1
    if word.endswith('e'):
        count -= 1
    if word.endswith('le'):
        count+=1
    if count == 0:
        count +=1
    return count


count = 0
for word in sys.argv[1:]:
    c = syllabes(word)
    count += c
#    print "word=%s %d" % (word, c)

print count

sys.exit(0)

dic = pyphen.Pyphen(lang='en')
count = 0
for word in sys.argv[1:]:
    c = dic.inserted(word)
    #count += c
    print "word=%s" % c

#print count
