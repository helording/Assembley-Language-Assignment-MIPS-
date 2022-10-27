
#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>

// constants

#define NCOLS 40
#define NROWS 20
#define MAX_LEN NCOLS
#define MAX_ITER 100
#define CLEAR "\033[H\033[2J"

// globals

int  wormCol[MAX_LEN];   // (col,row) coords of worm segments
int  wormRow[MAX_LEN];   // to simplify translation to MIPS, use
                         // pair of parallel arrays for (col,row)

char grid[NROWS][NCOLS]; // the grid, including worm chars

// functions (forward refs)

void giveUp(char *, char *);
void clearGrid();
void drawGrid();
void initWorm(int, int, int);
int  moveWorm(int);
void addWormToGrid(int);

// utilities
int  intValue(char *);
void seedRand(int);
int  randValue(int);
void delay(int);

// main function
int main(int argc, char **argv)
{
	int  startCol;  // initial X-coord of head (X = column)
	int  startRow;  // initial Y-coord of head (Y = row)
	int  length;    // # segments in worm (incl head)
	int  ntimes;    // # iterations
    int  seed;      // seed for random # generator

	if (argc < 4) giveUp(argv[0],NULL);
	length = intValue(argv[1]);
	if (length < 4 || length >= MAX_LEN)
		giveUp(argv[0], "Invalid Length (4..20)");
	ntimes = intValue(argv[2]);
	if (ntimes < 0 || ntimes >= MAX_ITER)
		giveUp(argv[0], "Invalid # Moves (0..99)");
	seed = intValue(argv[3]);
	if (seed < 0)
		giveUp(argv[0], "Invalid Rand Seed (0..Big)");
	seedRand(seed);

	// start worm roughly in middle of grid
	startCol = NCOLS/2 - length/2;
	startRow = NROWS/2;
	initWorm(startCol,startRow,length);
	for (int i = 0; i <= ntimes; i++) {
		clearGrid();
		addWormToGrid(length);
		printf(CLEAR);
		printf("Iteration %d\n",i);
		drawGrid();
#if 0
		for (int j = 0; j < length; j++)
			printf("(%d,%d) ",wormCol[j],wormRow[j]);
		printf("\n");
#endif
		if (!moveWorm(length)) {
			printf("Blocked!\n");
			break;
		}
		delay(1);
	}
	exit(EXIT_SUCCESS);
}

//clearGrid() ... set all grid[][] elements to '.'
void clearGrid()
{
    int row = 0;
    int col = 0;
    newbegin:
    col = 0;
    if(row < NROWS){
        sec:
        if(col < NCOLS){
            grid[row][col] = '.';
            col++;
            goto sec;
        }
        row++;
        goto newbegin;
    }

}

// drawGrid() ... display grid[][] matrix, row-by-row
void drawGrid()
{
	int row = 0;
    int col = 0;
    newbegin:
    col = 0;
    if(row < NROWS){
        sec:
        if(col < NCOLS){
            printf("%c",grid[row][col]);
            col++;
            goto sec;
        }
        row++;
        printf("\n");
        goto newbegin;
    }

}

// initWorm(col,row,len) ... set the wormCol[] and wormRow[]
//    arrays for a worm with head at (row,col) and body segements
//    on the same row and heading to the right (higher col values)
void initWorm(int col, int row, int len)
{
	int nsegs = 1;
	int newCol = col+1;
    wormCol[0] = col;
    wormRow[0] = row;
    newbegin:
    //newCol = col+1;
    if(newCol != NCOLS){
        if(nsegs < len){
            wormCol[nsegs] = newCol++;
		    wormRow[nsegs] = row;
		    nsegs++;
		    goto newbegin;
        }
    }    

}

// ongrid(col,row) ... checks whether (row,col)
//    is a valid coordinate for the grid[][] matrix

// col >= 0 && col < NCOLS (40) && row >=0 && row <NROWS (20)

int onGrid(int col, int row)
{
    int con1 = col;
    if(con1 >= 0){
        con1 = 1;
    }else{
        con1 = 0;
    }
    int con2 = col;
    if(con2 < 40){
        con2 = 1;
    } else{
        con2 = 0;
    }
    if(con1 == con2){
        con1 = 1;   
    }else{
        con1 = 0;
    }
    con2 = row;
    if(con2 >= 0){
        con2 = 1;
    } else{
        con2 = 0;
    }
    if(con1 == con2){
        con1 = 1;   
    }else{
        con1 = 0;
    }
    return con1;
}

// overlaps(r,c,len) ... checks whether (row,col) holds a body segment
int overlaps(int col, int row, int len)
{
    int i = 0;
    loop:
    if(i < len){
        if(wormCol[i] == col){
            if(wormRow[i] == row){
                return 1;
            }
        }
        i++;
        goto loop;
    }
    return 0;

}




int moveWorm(int len)
{
	int i; // index
	int n; // counter
	int row, col; // prospective rows and cols
	int possibleRow[8]; // (col,row) coords of possible places for segments
	int possibleCol[8];
    n = 0;
    int dx = -1;
    int dy = -1;
    loop1:
    if(dx <= 1){
        loop2:
        if(dy <= 1){
            col = wormCol[0] + dx;
			row = wormRow[0] + dy;
			if(onGrid(col,row) &&  !overlaps(col,row,len)){
				possibleCol[n] = col;
				possibleRow[n] = row;
				n++;
			}
			dy++;
			goto loop2;
        }
        dy = -1;
        dx++;
        goto loop1;
    }
    if(n == 0) return 0;
    i = len-1;
    loop3:
    if(i > 0){
        wormRow[i] = wormRow[i-1];
		wormCol[i] = wormCol[i-1];
		i--;
		goto loop3;
    }
    i = randValue(n);
	wormRow[0] = possibleRow[i];
	wormCol[0] = possibleCol[i];
	return 1;

}

// addWormTogrid(N) ... add N worm segments to grid[][] matrix
//    0'th segment is head, located at (wormRow[0],wormCol[0])
//    i'th segment located at (wormRow[i],wormCol[i]), for i > 0
void addWormToGrid(int len)
{   int row, col;
    row = wormRow[0];
	col = wormCol[0];
    grid[row][col] = '@';
    int i = 1;
    newbegin:
    if(i < len){
        row = wormRow[i];
		col = wormCol[i];
    	grid[row][col] = 'o';	
        i++;
        goto newbegin;
    }

}

// Utility functions

// print error message and exit
void giveUp(char *progName, char *errmsg)
{
	if (errmsg != NULL) printf("%s\n",errmsg);
	printf("Usage: %s Length #Moves Seed\n", progName);
	exit(EXIT_FAILURE);
}

// convert string of digits to integer
int intValue(char *str)
{
	char *s;
	int val = 0;
	for (s = str; *s != '\0'; s++) {
		if (*s == ' ') continue; // ignore spaces
		if (*s < '0' || *s > '9') return -1;
		val = val*10 + (*s-'0');
	}
	return val;
}

// waste some time
#if 0
void delay(int n)
{
	double x = 3.14;
	for (int i = 0; i < n; i++) {
		for (int j = 0; j < 40000; j++)
			for (int k = 0; k < 1000; k++)
				x = x + 1.0;
	}
}
#else
void delay(int n)
{
    int x = 3;
    int j = 0;
    int i = 0;
    int k = 0;
    loop:
    if(i<n){
        loop2:
        if(j < 40000){
            loop3:
            if(k < 1000){
                x = x * 3;
                k++;
                goto loop3;
            }
            k =0;
            j++;
            goto loop2;
        }
        i++;
        j= 0;
        goto loop;
    }
	/*int x = 3;
	for (int i = 0; i < n; i++) {
		for (int j = 0; j < 40000; j++)
			for (int k = 0; k < 1000; k++)
				x = x * 3;
	}*/
}
#endif

// random number generator

#define MAX_RAND ((1U << 31) - 1)
int randSeed = 0;

// initial seed for random # generator
void seedRand(int seed)
{
	randSeed = seed;
}

// generate random value in range 0..n-1
int randValue(int n)
{
	randSeed = (randSeed * 1103515245 + 12345) & RAND_MAX;
	return randSeed % n;
}
