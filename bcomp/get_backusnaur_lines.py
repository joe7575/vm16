Files = ["bparser", "bexpression"]

is_active = False
for filename in Files:
    for line in open(filename + ".lua").readlines():
        if line.strip() == "--[[":
            is_active = True
        elif line.strip() == "]]--":
            is_active = False
            print("")
        elif is_active:
            print(line, end="")
            
            
