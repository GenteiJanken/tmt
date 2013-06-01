import os

# splits a file with name filename into n separate files
# divides up a large corpus by an arbitrary factor
def file_split(filename, n):
    f = open(filename, 'r')
    fn, fext = os.path.splitext(filename)
    strings = []

    #obtain split file strings
    for i in range(n):
        strings.append('')

    i = 0
    
    for line in f:
        strings[i] += line
        i = (i + 1) % n 

    f.close()

    for i in range(n):
        name = fn + str(i) + fext
        f = open(name, 'w')
        f.write(strings[i])
        f.close()


file_split("mthesaur.txt", 10)
