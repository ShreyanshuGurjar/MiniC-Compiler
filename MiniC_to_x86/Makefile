a.out: a3.l a3.y
	bison -d a3.y
	flex a3.l
	g++ -o $@ a3.tab.c lex.yy.c -lfl
