/*
 * ocl_sha512.c
 *
 * hashkill - a hash cracking tool
 * Copyright (C) 2010 Milen Rangelov <gat3way@gat3way.eu>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 */

#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <pthread.h>
#include "err.h"
#include "ocl-base.h"
#include "ocl-threads.h"
#include "plugins.h"
#include "hashinterface.h"
#include "sessions.h"
#include "ocl_support.h"
#include "ocl-adl.h"
#include "hashgen.h"

#define Endian_Reverse64(a) { (a) = ((a) & 0x00000000000000FFULL) << 56 | ((a) & 0x000000000000FF00ULL) << 40 | \
                              ((a) & 0x0000000000FF0000ULL) << 24 | ((a) & 0x00000000FF000000ULL) << 8 | \
                              ((a) & 0x000000FF00000000ULL) >> 8 | ((a) & 0x0000FF0000000000ULL) >> 24 | \
                              ((a) & 0x00FF000000000000ULL) >> 40 | ((a) & 0xFF00000000000000ULL) >> 56; }

#define H3 0xa54ff53a5f1d36f1ULL


static void ocl_set_params(int loopnr, cl_ulong4 param1, cl_ulong4 param2,cl_ulong16 *p1, cl_ulong16 *p2)
{
    switch (loopnr)
    {
	case 0:
	    p1->s0=param1.s0;
	    p1->s1=param1.s1;
	    p1->s2=param1.s2;
	    p1->s3=param1.s3;
	    p2->s0=param2.s0;
	    p2->s1=param2.s1;
	    p2->s2=param2.s2;
	    p2->s3=param2.s3;
	    break;
	case 1:
	    p1->s4=param1.s0;
	    p1->s5=param1.s1;
	    p1->s6=param1.s2;
	    p1->s7=param1.s3;
	    p2->s4=param2.s0;
	    p2->s5=param2.s1;
	    p2->s6=param2.s2;
	    p2->s7=param2.s3;
	    break;
	case 2:
	    p1->s8=param1.s0;
	    p1->s9=param1.s1;
	    p1->sA=param1.s2;
	    p1->sB=param1.s3;
	    p2->s8=param2.s0;
	    p2->s9=param2.s1;
	    p2->sA=param2.s2;
	    p2->sB=param2.s3;
	    break;
	case 3:
	    p1->sC=param1.s0;
	    p1->sD=param1.s1;
	    p1->sE=param1.s2;
	    p1->sF=param1.s3;
	    p2->sC=param2.s0;
	    p2->sD=param2.s1;
	    p2->sE=param2.s2;
	    p2->sF=param2.s3;
	    break;
    }
}


static void ocl_get_cracked(cl_command_queue queuein,cl_mem plains_buf, char *plains, cl_mem hashes_buf, char *hashes, int numfound, int vsize, int hashlen)
{
    int a,b,e=0;
    char plain[16];
    struct hash_list_s  *mylist, *addlist;

    if (numfound>MAXFOUND) 
    {
	printf("error found=%d\n",numfound);
	return;
    }

    _clEnqueueReadBuffer(queuein, plains_buf, CL_TRUE, 0, 16*numfound*vsize, plains, 0, NULL, NULL);
    _clEnqueueReadBuffer(queuein, hashes_buf, CL_TRUE, 0, hashlen*numfound*vsize, hashes, 0, NULL, NULL);

    for (a=0;a<numfound;a++)
    for (b=0;b<vsize;b++)
    if (hash_index[hashes[(a*vsize+b)*hashlen]&255][hashes[(a*vsize+b)*hashlen+1]&255].nodes)
    {
    	e=a*vsize+b;
	mylist = hash_index[hashes[e*hashlen]&255][hashes[e*hashlen+1]&255].nodes;
	while (mylist)
	{
    	    if (memcmp(mylist->hash, (char *)hashes+(e)*hashlen, hash_ret_len) == 0)
    	    {
        	int flag = 0;
        	memcpy(plain,&plains[0]+(e*16),16);
        	plain[strlen(plain)-1] = 0;
        	pthread_mutex_lock(&crackedmutex);
        	addlist = cracked_list;
        	while (addlist)
        	{
            	    if ( /*(strcmp(addlist->username, mylist->username) == 0) &&*/ (memcmp(addlist->hash, mylist->hash, hash_ret_len) == 0))
                        flag = 1;
            	    addlist = addlist->next;
        	}
        	pthread_mutex_unlock(&crackedmutex);
        	if (flag == 0)
        	{
            	    add_cracked_list(mylist->username, mylist->hash, mylist->salt, plain);
        	}
    	    }
    	    mylist = mylist->indexnext;
        }
    }
}

static void markov_sched_setlimits()
{
    int a,b,c;
    int e1,e2,e3,etemp,charset_size=strlen(markov_charset);\

    e1=e2=e3=0;
    if (fast_markov == 1)
    {
	charset_size = charset_size - 23;
	if (session_restore_flag==0) markov_threshold = (markov_threshold*3)/2;
    }
    reduced_size=0;
    for (a=0;a<charset_size;a++) if (markov0[a]>markov_threshold)
    {
	reduced_charset[reduced_size]=markov_charset[a];
	// Create markov2 table
	for (b=0;b<strlen(markov_charset);b++) markov2[reduced_size][b] = markov1[a][b];
	reduced_size++;
	reduced_charset[reduced_size]=0;
    }

    if (session_restore_flag==0)
    {
	scheduler.markov_l1 = reduced_size;
	for (a=0;a<reduced_size;a++)
	{
	    etemp = 0;
	    for (b=0;b<strlen(markov_charset);b++)
	    if (markov2[a][b]>markov_threshold) etemp++;

	    if (etemp>0)
	    {
		e1=a;
		e2=etemp;
	    }
	    scheduler.ebitmap2[a]=etemp;
	}
	scheduler.markov_l2_1 = e1;
	scheduler.markov_l2_2 = e2;

	for (a=0;a<reduced_size;a++)
	for (b=0;b<strlen(markov_charset);b++)
	if (markov2[a][b]>markov_threshold)
	{
	    etemp = 0;
	    for (c=0;c<strlen(markov_charset);c++)
	    if (markov1[b][c]>markov_threshold) etemp++;

	    if (etemp>0)
	    {
		e1=a;
		e2=b;
		e3=etemp;
	    }
	    scheduler.ebitmap3[a][b]=etemp;
	}
	else scheduler.ebitmap3[a][b]=0;
	scheduler.markov_l3_1 = e1;
	scheduler.markov_l3_2 = e2;
	scheduler.markov_l3_3 = e3;
    }
}



/* Markov initializer */
static void init_markov()
{
    int a,b,charset_size;

    charset_size = strlen(markov_charset);
    bitmaps = malloc(256*256*32*8*4);
    table = malloc(charset_size*charset_size*charset_size*4);
    if (fast_markov == 1)
    {
	charset_size = charset_size - 23;
	if (session_restore_flag==0) markov_threshold = (markov_threshold*3)/2;
    }
    reduced_size=0;
    for (a=0;a<charset_size;a++) if (markov0[a]>markov_threshold)
    {
	reduced_charset[reduced_size]=markov_charset[a];
	// Create markov2 table
	for (b=0;b<strlen(markov_charset);b++) markov2[reduced_size][b] = markov1[a][b];
	reduced_size++;
	reduced_charset[reduced_size]=0;
    }

    for (a=0;a<strlen(markov_charset);a++)
    for (b=0;b<strlen(markov_charset);b++)
    {
	table[a*strlen(markov_charset)+b] = (markov_charset[a]<<8)|(markov_charset[b]);
    }

    for (a=0;a<256*256*32*8;a++)
    {
	    bitmaps[a]=0;
    }
}

/* Markov deinit */
static void deinit_markov()
{
    free(bitmaps);
    free(table);
}


/* Bruteforce initializer big charsets */
static void init_bruteforce_long()
{
    int a,b;

    bitmaps = malloc(256*256*32*8*4);
    table = malloc(128*128*4);

    for (a=0;a<strlen(bruteforce_charset);a++)
    for (b=0;b<strlen(bruteforce_charset);b++)
    {
	table[a*strlen(bruteforce_charset)+b] = (bruteforce_charset[a]<<8)|(bruteforce_charset[b]);
    }

    for (a=0;a<256*256*8*32;a++)
    {
	    bitmaps[a]=0;
    }
}


/* Bruteforce deinit */
static void deinit_bruteforce()
{
    free(bitmaps);
    free(table);
}



/* Execute kernel, flush parameters */
static void ocl_execute(cl_command_queue queue, cl_kernel kernel, size_t *global_work_size, size_t *local_work_size, int charset_size, cl_mem found_buf, cl_mem hashes_buf, cl_mem plains_buf, char *plains, char *hashes,int self, cl_ulong16 *p1,cl_ulong16 *p2)
{
    int err;
    int *found;
    int try;
    size_t lglobal_work_size[3];
    size_t offset[3];

    _clSetKernelArg(kernel, 6, sizeof(cl_ulong16), (void*) p1);
    _clSetKernelArg(kernel, 7, sizeof(cl_ulong16), (void*) p2);

    if (interactive_mode==1)
    {
	for (try=0;try<32;try++)
	{
	    if (attack_over>0) return;
	    lglobal_work_size[0]=global_work_size[0];
	    lglobal_work_size[1]=(global_work_size[1]+31)/32;
	    offset[1] = try*lglobal_work_size[1];
	    offset[0] = 0;
	    if (attack_over!=0) pthread_exit(NULL);
	    _clEnqueueNDRangeKernel(queue, kernel, 2, offset, lglobal_work_size, local_work_size, 0, NULL, NULL);
	    found = _clEnqueueMapBuffer(queue, found_buf, CL_TRUE,CL_MAP_READ, 0, 4, 0, 0, NULL, &err);
	    if (*found>0) 
	    {
    		ocl_get_cracked(queue,plains_buf,plains, hashes_buf,hashes, *found, wthreads[self].vectorsize, hash_ret_len);
    		bzero(plains,16*8*MAXFOUND);
    		_clEnqueueWriteBuffer(queue, plains_buf, CL_FALSE, 0, 16*8*MAXFOUND, plains, 0, NULL, NULL);
    		// Change for other types
    		bzero(hashes,hash_ret_len*8*MAXFOUND);
    		_clEnqueueWriteBuffer(queue, hashes_buf, CL_FALSE, 0, hash_ret_len*8*MAXFOUND, hashes, 0, NULL, NULL);
    		*found = 0;
    		_clEnqueueWriteBuffer(queue, found_buf, CL_FALSE, 0, 4, found, 0, NULL, NULL);
	    }
    	    _clEnqueueUnmapMemObject(queue,found_buf,(void *)found,0,NULL,NULL);
	    wthreads[self].tries += (charset_size*charset_size*charset_size*charset_size*wthreads[self].loops)/32;
	}
    }
    else
    {
	for (try=0;try<16;try++)
	{
	    if (attack_over>0) return;
	    lglobal_work_size[0]=global_work_size[0];
	    lglobal_work_size[1]=(global_work_size[1]+16)/16;
	    offset[1] = try*lglobal_work_size[1];
	    offset[0] = 0;
	    if (attack_over!=0) pthread_exit(NULL);
	    _clEnqueueNDRangeKernel(queue, kernel, 2, offset, lglobal_work_size, local_work_size, 0, NULL, NULL);
	    found = _clEnqueueMapBuffer(queue, found_buf, CL_TRUE,CL_MAP_READ, 0, 4, 0, 0, NULL, &err);
	    if (*found>0) 
	    {
    		ocl_get_cracked(queue,plains_buf,plains, hashes_buf,hashes, *found, wthreads[self].vectorsize, hash_ret_len);
    		bzero(plains,16*8*MAXFOUND);
    		_clEnqueueWriteBuffer(queue, plains_buf, CL_FALSE, 0, 16*8*MAXFOUND, plains, 0, NULL, NULL);
    		// Change for other types
    		bzero(hashes,hash_ret_len*8*MAXFOUND);
    		_clEnqueueWriteBuffer(queue, hashes_buf, CL_FALSE, 0, hash_ret_len*8*MAXFOUND, hashes, 0, NULL, NULL);
    		*found = 0;
    		_clEnqueueWriteBuffer(queue, found_buf, CL_FALSE, 0, 4, found, 0, NULL, NULL);
	    }
    	    _clEnqueueUnmapMemObject(queue,found_buf,(void *)found,0,NULL,NULL);
	    wthreads[self].tries += (charset_size*charset_size*charset_size*charset_size*wthreads[self].loops)/16;
	}
    }
    attack_current_count += wthreads[self].loops;
}





/* Bruteforce larger charsets */
void* ocl_bruteforce_sha512_thread(void *arg)
{
    int err;
    cl_command_queue queue;
    cl_mem hashes_buf;
    size_t global_work_size[3];
    cl_ulong4 image;
    unsigned char hex1[hash_ret_len];
    int self;
    cl_kernel kernel;
    cl_mem bitmaps_buf;
    int a;
    int a1,a2,a3,a4,a5,a6,a7,a8,a9,a10,a11;
    int try=0;
    char *hashes;
    int charset_size = (int)strlen(bruteforce_charset);
    cl_mem plains_buf;
    char *plains;
    int found;
    cl_mem found_buf;
    struct  hash_list_s  *mylist;
    cl_uint csize;
    cl_mem table_buf;
    cl_ulong16 p1;
    cl_ulong16 p2;
    cl_ulong4 singlehash;
    size_t nvidia_local_work_size[3]={64,1,0};
    size_t amd_local_work_size[3]={64,1,0};
    size_t *local_work_size;

    /* Lock and load! */
    pthread_mutex_lock(&biglock);
    memcpy(&self,arg,sizeof(int));

    /* Setup local work size */
    if (wthreads[self].type==nv_thread) local_work_size = nvidia_local_work_size;
    else local_work_size = amd_local_work_size;

    /* Init kernels */
    if (ocl_gpu_double) kernel = _clCreateKernel(program[self], "sha512_long_double", &err );
    else  kernel = _clCreateKernel(program[self], "sha512_long_normal", &err );

    /* Create queue */
    queue = _clCreateCommandQueue(context[self], wthreads[self].cldeviceid, 0, &err );


    mylist = hash_list;
    a=0;
    while (mylist)
    {
        memcpy(hex1,mylist->hash,hash_ret_len);
	a++;
	unsigned int *b_a = (unsigned int *)hex1;
	unsigned int *b_b = (unsigned int *)&hex1[4];
	unsigned int *b_c = (unsigned int *)&hex1[8];
	unsigned int *b_d = (unsigned int *)&hex1[12];
	unsigned int bind_a = (*b_a)>>10;
	unsigned int bval_a = (1<<((*b_a)&31));
	unsigned int bind_b = (*b_b)>>10;
	unsigned int bval_b = (1<<((*b_b)&31));
	unsigned int bind_c = (*b_c)>>10;
	unsigned int bval_c = (1<<((*b_c)&31));
	unsigned int bind_d = (*b_d)>>10;
	unsigned int bval_d = (1<<((*b_d)&31));
	bitmaps[bind_a] |=bval_a;
	bitmaps[bind_b+65535*8*8] |=bval_b;
	bitmaps[bind_c+65535*16*8] |=bval_c;
	bitmaps[bind_d+65535*24*8] |=bval_d;
	singlehash.x |= (1<<((*b_b)&31));
	singlehash.y |= (1<<((*b_c)&31));
	singlehash.z |= (1<<((*b_d)&31));
        if (mylist) mylist = mylist->next;
	singlehash.w=0;
	p2.s0=p2.s4=p2.s8=p2.sC=singlehash.x;
	p2.s1=p2.s5=p2.s9=p2.sD=singlehash.y;
	p2.s2=p2.s6=p2.sA=p2.sE=singlehash.z;
	p2.s3=p2.s7=p2.sB=p2.sF=singlehash.z;
    }
   if (a==1)
   {
        mylist = hash_list;
        memcpy(hex1,mylist->hash,8);
        memcpy(&singlehash.x, hex1, 8);
        memcpy(hex1,mylist->hash+8,8);
        memcpy(&singlehash.y, hex1, 8);
        memcpy(hex1,mylist->hash+16,8);
        memcpy(&singlehash.z, hex1, 8);
        memcpy(hex1,mylist->hash+24,8);
        memcpy(&singlehash.w, hex1, 8);
        Endian_Reverse64(singlehash.w);
        singlehash.w-=H3;
    }


    // Change for other lens
    hashes  = malloc(hash_ret_len*8*MAXFOUND); 
    hashes_buf = _clCreateBuffer(context[self], CL_MEM_WRITE_ONLY, hash_ret_len*8*MAXFOUND, NULL, &err );
    plains=malloc(16*8*MAXFOUND);
    bzero(plains,16*8*MAXFOUND);
    plains_buf = _clCreateBuffer(context[self], CL_MEM_WRITE_ONLY, 16*8*MAXFOUND, NULL, &err );
    _clEnqueueWriteBuffer(queue, plains_buf, CL_TRUE, 0, 16*8*MAXFOUND, plains, 0, NULL, NULL);
    // Change for other types
    bzero(hashes,hash_ret_len*8*MAXFOUND);
    _clEnqueueWriteBuffer(queue, hashes_buf, CL_TRUE, 0, hash_ret_len*8*MAXFOUND, hashes, 0, NULL, NULL);


    found_buf = _clCreateBuffer(context[self], CL_MEM_READ_WRITE, 4, NULL, &err );
    table_buf = _clCreateBuffer(context[self], CL_MEM_READ_ONLY|CL_MEM_USE_HOST_PTR, 128*128*4,table , &err );
    bitmaps_buf = _clCreateBuffer(context[self], CL_MEM_READ_ONLY|CL_MEM_USE_HOST_PTR, 256*256*32*8*4, bitmaps, &err );
    found = 0;
    _clEnqueueWriteBuffer(queue, found_buf, CL_TRUE, 0, 4, &found, 0, NULL, NULL);


    _clSetKernelArg(kernel, 0, sizeof(cl_mem), (void*) &hashes_buf);
    _clSetKernelArg(kernel, 1, sizeof(cl_uint), (void*) &csize);
    _clSetKernelArg(kernel, 2, sizeof(cl_mem), (void*) &plains_buf);
    _clSetKernelArg(kernel, 3, sizeof(cl_mem), (void*) &bitmaps_buf);
    _clSetKernelArg(kernel, 4, sizeof(cl_mem), (void*) &found_buf);
    _clSetKernelArg(kernel, 5, sizeof(cl_mem), (void*) &table_buf);


    global_work_size[0] = (charset_size*charset_size);
    global_work_size[1] = (charset_size*charset_size);
    while ((global_work_size[0] % local_work_size[0])!=0) global_work_size[0]++;
    while ((global_work_size[1] % (wthreads[self].vectorsize))!=0) global_work_size[1]++;
    global_work_size[1] = global_work_size[1]/wthreads[self].vectorsize;
    image.x=image.y=image.z=image.w=0;
    pthread_mutex_unlock(&biglock); 



    /* Bruteforce, len=4 */

    csize=4<<3;
    _clSetKernelArg(kernel, 1, sizeof(uint), (void*) &csize);
    pthread_mutex_lock(&wthreads[self].tempmutex);
    pthread_mutex_unlock(&wthreads[self].tempmutex);
    if (attack_over!=0) goto out;
    image.x=0;image.y=0x80;image.z=0;image.w=0;
    ocl_set_params(try,image,singlehash,&p1,&p2);

    _clSetKernelArg(kernel, 6, sizeof(cl_ulong16), (void*) &p1);
    _clSetKernelArg(kernel, 7, sizeof(cl_ulong16), (void*) &p2);
    try=0;
    ocl_execute(queue, kernel, global_work_size, local_work_size, charset_size, found_buf, hashes_buf, plains_buf, plains, hashes, self, &p1,&p2);
    if (bruteforce_end==4) goto out;
    if ((session_restore_flag==0)&&(self==0)) scheduler.len=5;


    /* bruteforce, len=5 */

    csize=5<<3;
    sched_wait(5);
    _clSetKernelArg(kernel, 1, sizeof(uint), (void*) &csize);
    if (sched_len()==5)
    if (bruteforce_end>=5)
    while ((sched_len()==5)&&((a1=sched_s1())<sched_e1()))
    {
        pthread_mutex_lock(&wthreads[self].tempmutex);
        pthread_mutex_unlock(&wthreads[self].tempmutex);
	if (attack_over!=0) goto out;
    	image.x=0;
        image.y=bruteforce_charset[a1]|(0x80<<8);
        image.z=0;image.w=0;
    	ocl_set_params(try,image,singlehash,&p1,&p2);

	try++;
	if (try==wthreads[self].loops)
	{
	    ocl_execute(queue, kernel, global_work_size, local_work_size, charset_size, found_buf, hashes_buf, plains_buf, plains, hashes, self, &p1,&p2);
	    try=0;
	}
    }
    ocl_execute(queue, kernel, global_work_size, local_work_size, charset_size, found_buf, hashes_buf, plains_buf, plains, hashes, self, &p1,&p2);

    /* bruteforce, len=6 */
    csize=6<<3;
    sched_wait(6);
    _clSetKernelArg(kernel, 1, sizeof(uint), (void*) &csize);
    if (sched_len()==6)
    if (bruteforce_end>=6)
    for (a1=0;a1<charset_size;a1++)
    while ((sched_len()==6)&&((a2=sched_s2(a1))<sched_e2(a1)))
    {
        pthread_mutex_lock(&wthreads[self].tempmutex);
        pthread_mutex_unlock(&wthreads[self].tempmutex);
	if (attack_over!=0) goto out;

    	image.x=0;
    	image.y=bruteforce_charset[a1]|(bruteforce_charset[a2]<<8)|(0x80<<16);
    	image.z=0;image.w=0;
    	ocl_set_params(try,image,singlehash,&p1,&p2);

	try++;
	if (try==wthreads[self].loops)
	{
	    ocl_execute(queue, kernel, global_work_size, local_work_size, charset_size, found_buf, hashes_buf, plains_buf, plains, hashes, self, &p1,&p2);
	    try=0;
	}
    }
    ocl_execute(queue, kernel, global_work_size, local_work_size, charset_size, found_buf, hashes_buf, plains_buf, plains, hashes, self, &p1,&p2);


    /* bruteforce, len=7 */

    csize=7<<3;
    sched_wait(7);
    _clSetKernelArg(kernel, 1, sizeof(uint), (void*) &csize);
    if (sched_len()==7)
    if (bruteforce_end>=7)
    for (a1=0;a1<charset_size;a1++)
    for (a2=0;a2<charset_size;a2++)
    while ((sched_len()==7)&&((a3=sched_s3(a1,a2))<sched_e3(a1,a2)))
    {
        pthread_mutex_lock(&wthreads[self].tempmutex);
        pthread_mutex_unlock(&wthreads[self].tempmutex);
	if (attack_over!=0) goto out;

    	image.x=0;
    	image.y=bruteforce_charset[a1]|(bruteforce_charset[a2]<<8)|(bruteforce_charset[a3]<<16)|(0x80<<24);
    	image.z=0;image.w=0;
    	ocl_set_params(try,image,singlehash,&p1,&p2);

	try++;
	if (try==wthreads[self].loops)
	{
	    ocl_execute(queue, kernel, global_work_size, local_work_size, charset_size, found_buf, hashes_buf, plains_buf, plains, hashes, self, &p1,&p2);
	    try=0;
	}
    }
    ocl_execute(queue, kernel, global_work_size, local_work_size, charset_size, found_buf, hashes_buf, plains_buf, plains, hashes, self, &p1,&p2);



    /* bruteforce, len=8 */

    csize=8<<3;
    sched_wait(8);
    _clSetKernelArg(kernel, 1, sizeof(uint), (void*) &csize);
    if (sched_len()==8)
    if (bruteforce_end>=8)
    for (a1=0;a1<charset_size;a1++)
    for (a2=0;a2<charset_size;a2++)
    while ((sched_len()==8)&&((a3=sched_s3(a1,a2))<sched_e3(a1,a2)))
    for (a4=0;a4<charset_size;a4++) 
    {
        pthread_mutex_lock(&wthreads[self].tempmutex);
        pthread_mutex_unlock(&wthreads[self].tempmutex);
	if (attack_over!=0) goto out;

    	image.x=0;
    	image.y=bruteforce_charset[a1]|(bruteforce_charset[a2]<<8)|(bruteforce_charset[a3]<<16)|(bruteforce_charset[a4]<<24);
    	image.z=0x80;
    	image.w=0;
    	ocl_set_params(try,image,singlehash,&p1,&p2);

	try++;
	if (try==wthreads[self].loops)
	{
	    ocl_execute(queue, kernel, global_work_size, local_work_size, charset_size, found_buf, hashes_buf, plains_buf, plains, hashes, self, &p1,&p2);
	    try=0;
	}
    }
    ocl_execute(queue, kernel, global_work_size, local_work_size, charset_size, found_buf, hashes_buf, plains_buf, plains, hashes, self, &p1,&p2);


    /* bruteforce, len=9 */
    csize=9<<3;
    sched_wait(9);
    _clSetKernelArg(kernel, 1, sizeof(uint), (void*) &csize);
    if (sched_len()==9)
    if (bruteforce_end>=9)
    for (a1=0;a1<charset_size;a1++)
    for (a2=0;a2<charset_size;a2++)
    while ((sched_len()==9)&&((a3=sched_s3(a1,a2))<sched_e3(a1,a2)))
    for (a4=0;a4<charset_size;a4++) 
    for (a5=0;a5<charset_size;a5++) 
    {
        pthread_mutex_lock(&wthreads[self].tempmutex);
        pthread_mutex_unlock(&wthreads[self].tempmutex);
	if (attack_over!=0) goto out;

    	image.x=0;
    	image.y=bruteforce_charset[a1]|(bruteforce_charset[a2]<<8)|(bruteforce_charset[a3]<<16)|(bruteforce_charset[a4]<<24);
    	image.z=(bruteforce_charset[a5])|(0x80<<8);
    	image.w=0;
    	ocl_set_params(try,image,singlehash,&p1,&p2);

	try++;
	if (try==wthreads[self].loops)
	{
	    ocl_execute(queue, kernel, global_work_size, local_work_size, charset_size, found_buf, hashes_buf, plains_buf, plains, hashes, self, &p1,&p2);
	    try=0;
	}
    }
    ocl_execute(queue, kernel, global_work_size, local_work_size, charset_size, found_buf, hashes_buf, plains_buf, plains, hashes, self, &p1,&p2);


    /* bruteforce, len=10 */

    csize=10<<3;
    sched_wait(10);
    _clSetKernelArg(kernel, 1, sizeof(uint), (void*) &csize);
    if (sched_len()==10)
    if (bruteforce_end>=10)
    for (a1=0;a1<charset_size;a1++)
    for (a2=0;a2<charset_size;a2++)
    while ((sched_len()==10)&&((a3=sched_s3(a1,a2))<sched_e3(a1,a2)))
    for (a4=0;a4<charset_size;a4++) 
    for (a5=0;a5<charset_size;a5++) 
    for (a6=0;a6<charset_size;a6++) 
    {
        pthread_mutex_lock(&wthreads[self].tempmutex);
        pthread_mutex_unlock(&wthreads[self].tempmutex);
	if (attack_over!=0) goto out;

    	image.x=0;
    	image.y=bruteforce_charset[a1]|(bruteforce_charset[a2]<<8)|(bruteforce_charset[a3]<<16)|(bruteforce_charset[a4]<<24);
    	image.z=(bruteforce_charset[a5])|(bruteforce_charset[a6]<<8)|(0x80<<16);
    	image.w=0;
    	ocl_set_params(try,image,singlehash,&p1,&p2);

	try++;
	if (try==wthreads[self].loops)
	{
	    ocl_execute(queue, kernel, global_work_size, local_work_size, charset_size, found_buf, hashes_buf, plains_buf, plains, hashes, self, &p1,&p2);
	    try=0;
	}
    }
    ocl_execute(queue, kernel, global_work_size, local_work_size, charset_size, found_buf, hashes_buf, plains_buf, plains, hashes, self, &p1,&p2);


    /* bruteforce, len=11 */

    csize=11<<3;
    sched_wait(11);
    _clSetKernelArg(kernel, 1, sizeof(uint), (void*) &csize);
    if (sched_len()==11)
    if (bruteforce_end>=11)
    for (a1=0;a1<charset_size;a1++)
    for (a2=0;a2<charset_size;a2++)
    while ((sched_len()==11)&&((a3=sched_s3(a1,a2))<sched_e3(a1,a2)))
    for (a4=0;a4<charset_size;a4++) 
    for (a5=0;a5<charset_size;a5++) 
    for (a6=0;a6<charset_size;a6++) 
    for (a7=0;a7<charset_size;a7++)
    {
        pthread_mutex_lock(&wthreads[self].tempmutex);
        pthread_mutex_unlock(&wthreads[self].tempmutex);
	if (attack_over!=0) goto out;

    	image.x=0;
    	image.y=bruteforce_charset[a1]|(bruteforce_charset[a2]<<8)|(bruteforce_charset[a3]<<16)|(bruteforce_charset[a4]<<24);
    	image.z=(bruteforce_charset[a5])|(bruteforce_charset[a6]<<8)|(bruteforce_charset[a7]<<16)|(0x80<<24);
    	image.w=0;
    	ocl_set_params(try,image,singlehash,&p1,&p2);

	try++;
	if (try==wthreads[self].loops)
	{
	    ocl_execute(queue, kernel, global_work_size, local_work_size, charset_size, found_buf, hashes_buf, plains_buf, plains, hashes, self, &p1,&p2);
	    try=0;
	}
    }
    ocl_execute(queue, kernel, global_work_size, local_work_size, charset_size, found_buf, hashes_buf, plains_buf, plains, hashes, self, &p1,&p2);


    /* bruteforce, len=12 */

    csize=12<<3;
    sched_wait(12);
    if (sched_len()==12)
    if (bruteforce_end>=12)
    for (a1=0;a1<charset_size;a1++)
    for (a2=0;a2<charset_size;a2++)
    while ((sched_len()==12)&&((a3=sched_s3(a1,a2))<sched_e3(a1,a2)))
    for (a4=0;a4<charset_size;a4++) 
    for (a5=0;a5<charset_size;a5++) 
    for (a6=0;a6<charset_size;a6++) 
    for (a7=0;a7<charset_size;a7++)
    for (a8=0;a8<charset_size;a8++) 
    {
        pthread_mutex_lock(&wthreads[self].tempmutex);
        pthread_mutex_unlock(&wthreads[self].tempmutex);
	if (attack_over!=0) goto out;

    	image.x=0;
    	image.y=bruteforce_charset[a1]|(bruteforce_charset[a2]<<8)|(bruteforce_charset[a3]<<16)|(bruteforce_charset[a4]<<24);
    	image.z=(bruteforce_charset[a5])|(bruteforce_charset[a6]<<8)|(bruteforce_charset[a7]<<16)|(bruteforce_charset[a8]<<24);
    	image.w=(cl_ulong)(0x80);
    	image.z=image.z|(image.w<<32);
    	ocl_set_params(try,image,singlehash,&p1,&p2);

	try++;
	if (try==wthreads[self].loops)
	{
	    ocl_execute(queue, kernel, global_work_size, local_work_size, charset_size, found_buf, hashes_buf, plains_buf, plains, hashes, self, &p1,&p2);
	    try=0;
	}
    }
    ocl_execute(queue, kernel, global_work_size, local_work_size, charset_size, found_buf, hashes_buf, plains_buf, plains, hashes, self, &p1,&p2);


    /* bruteforce, len=13 */

    csize=13<<3;
    sched_wait(13);
    if (sched_len()==13)
    if (bruteforce_end>=13)
    for (a1=0;a1<charset_size;a1++)
    for (a2=0;a2<charset_size;a2++)
    while ((sched_len()==13)&&((a3=sched_s3(a1,a2))<sched_e3(a1,a2)))
    for (a4=0;a4<charset_size;a4++) 
    for (a5=0;a5<charset_size;a5++) 
    for (a6=0;a6<charset_size;a6++) 
    for (a7=0;a7<charset_size;a7++)
    for (a8=0;a8<charset_size;a8++) 
    for (a9=0;a9<charset_size;a9++) 
    {
        pthread_mutex_lock(&wthreads[self].tempmutex);
        pthread_mutex_unlock(&wthreads[self].tempmutex);
	if (attack_over!=0) goto out;

    	image.x=0;
    	image.y=bruteforce_charset[a1]|(bruteforce_charset[a2]<<8)|(bruteforce_charset[a3]<<16)|(bruteforce_charset[a4]<<24);
    	image.z=(bruteforce_charset[a5])|(bruteforce_charset[a6]<<8)|(bruteforce_charset[a7]<<16)|(bruteforce_charset[a8]<<24);
    	image.w=(cl_ulong)(bruteforce_charset[a9])|(0x80<<8);
    	image.z|=(image.w<<32);
    	ocl_set_params(try,image,singlehash,&p1,&p2);

	try++;
	if (try==wthreads[self].loops)
	{
	    ocl_execute(queue, kernel, global_work_size, local_work_size, charset_size, found_buf, hashes_buf, plains_buf, plains, hashes, self, &p1,&p2);
	    try=0;
	}
    }
    ocl_execute(queue, kernel, global_work_size, local_work_size, charset_size, found_buf, hashes_buf, plains_buf, plains, hashes, self, &p1,&p2);


    /* bruteforce, len=14 */

    csize=14<<3;
    sched_wait(14);
    if (sched_len()==14)
    if (bruteforce_end>=14)
    for (a1=0;a1<charset_size;a1++)
    for (a2=0;a2<charset_size;a2++)
    while ((sched_len()==13)&&((a3=sched_s3(a1,a2))<sched_e3(a1,a2)))
    for (a4=0;a4<charset_size;a4++) 
    for (a5=0;a5<charset_size;a5++) 
    for (a6=0;a6<charset_size;a6++) 
    for (a7=0;a7<charset_size;a7++)
    for (a8=0;a8<charset_size;a8++) 
    for (a9=0;a9<charset_size;a9++) 
    for (a10=0;a10<charset_size;a10++) 
    {
        pthread_mutex_lock(&wthreads[self].tempmutex);
        pthread_mutex_unlock(&wthreads[self].tempmutex);
	if (attack_over!=0) goto out;

    	image.x=0;
    	image.y=bruteforce_charset[a1]|(bruteforce_charset[a2]<<8)|(bruteforce_charset[a3]<<16)|(bruteforce_charset[a4]<<24);
    	image.z=(bruteforce_charset[a5])|(bruteforce_charset[a6]<<8)|(bruteforce_charset[a7]<<16)|(bruteforce_charset[a8]<<24);
    	image.w=(cl_ulong)(bruteforce_charset[a9])|(bruteforce_charset[a10]<<8)|(0x80<<16);
    	image.z=image.z|(image.w<<32);
    	ocl_set_params(try,image,singlehash,&p1,&p2);

	try++;
	if (try==wthreads[self].loops)
	{
	    ocl_execute(queue, kernel, global_work_size, local_work_size, charset_size, found_buf, hashes_buf, plains_buf, plains, hashes, self, &p1,&p2);
	    try=0;
	}
    }
    ocl_execute(queue, kernel, global_work_size, local_work_size, charset_size, found_buf, hashes_buf, plains_buf, plains, hashes, self, &p1,&p2);


    /* bruteforce, len=15 */

    csize=15<<3;
    sched_wait(15);
    if (sched_len()==15)
    if (bruteforce_end>=15)
    for (a1=0;a1<charset_size;a1++)
    for (a2=0;a2<charset_size;a2++)
    while ((sched_len()==15)&&((a3=sched_s3(a1,a2))<sched_e3(a1,a2)))
    for (a4=0;a4<charset_size;a4++) 
    for (a5=0;a5<charset_size;a5++) 
    for (a6=0;a6<charset_size;a6++) 
    for (a7=0;a7<charset_size;a7++)
    for (a8=0;a8<charset_size;a8++) 
    for (a9=0;a9<charset_size;a9++) 
    for (a10=0;a10<charset_size;a10++) 
    for (a11=0;a11<charset_size;a11++) 
    {
        pthread_mutex_lock(&wthreads[self].tempmutex);
        pthread_mutex_unlock(&wthreads[self].tempmutex);
	if (attack_over!=0) goto out;

    	image.x=0;
    	image.y=bruteforce_charset[a1]|(bruteforce_charset[a2]<<8)|(bruteforce_charset[a3]<<16)|(bruteforce_charset[a4]<<24);
    	image.z=(bruteforce_charset[a5])|(bruteforce_charset[a6]<<8)|(bruteforce_charset[a7]<<16)|(bruteforce_charset[a8]<<24);
    	image.w=(cl_ulong)(bruteforce_charset[a9])|(bruteforce_charset[a10]<<8)|(bruteforce_charset[a11]<<16)|(0x80<<24);
    	image.z=image.z|(image.w<<32);
    	ocl_set_params(try,image,singlehash,&p1,&p2);

	try++;
	if (try==wthreads[self].loops)
	{
	    ocl_execute(queue, kernel, global_work_size, local_work_size, charset_size, found_buf, hashes_buf, plains_buf, plains, hashes, self, &p1,&p2);
	    try=0;
	}
    }
    ocl_execute(queue, kernel, global_work_size, local_work_size, charset_size, found_buf, hashes_buf, plains_buf, plains, hashes, self, &p1,&p2);


    out:
    free(hashes);
    free(plains);
    return hash_ok;
}





void* ocl_markov_sha512_thread(void *arg)
{
    int err;
    cl_command_queue queue;
    cl_mem hashes_buf;
    size_t global_work_size[3];
    cl_ulong4 image;
    unsigned char hex1[hash_ret_len];
    int self;
    cl_kernel kernel;
    cl_mem bitmaps_buf;
    int a;
    int a1,a2,a3,a4,a5,a6,a7,a8;
    int try=0;
    char *hashes;
    int charset_size = (int)strlen(markov_charset);
    cl_mem plains_buf;
    char *plains;
    int found;
    cl_mem found_buf;
    struct  hash_list_s  *mylist;
    cl_uint csize;
    cl_mem table_buf;
    cl_ulong16 p1;
    cl_ulong16 p2;
    cl_ulong4 singlehash;
    size_t nvidia_local_work_size[3]={64,1,0};
    size_t amd_local_work_size[3]={64,1,0};
    size_t *local_work_size;

    /* Lock and load! */
    pthread_mutex_lock(&biglock);
    memcpy(&self,arg,sizeof(int));

    /* Setup local work size */
    if (wthreads[self].type==nv_thread) local_work_size = nvidia_local_work_size;
    else local_work_size = amd_local_work_size;

    /* Init kernels */
    if (ocl_gpu_double) kernel = _clCreateKernel(program[self], "sha512_long_double", &err );
    else  kernel = _clCreateKernel(program[self], "sha512_long_normal", &err );

    /* Create queue */
    queue = _clCreateCommandQueue(context[self], wthreads[self].cldeviceid, 0, &err );

    mylist = hash_list;
    a=0;
    while (mylist)
    {
        memcpy(hex1,mylist->hash,hash_ret_len);
	a++;
	unsigned int *b_a = (unsigned int *)hex1;
	unsigned int *b_b = (unsigned int *)&hex1[4];
	unsigned int *b_c = (unsigned int *)&hex1[8];
	unsigned int *b_d = (unsigned int *)&hex1[12];
	unsigned int bind_a = (*b_a)>>10;
	unsigned int bval_a = (1<<((*b_a)&31));
	unsigned int bind_b = (*b_b)>>10;
	unsigned int bval_b = (1<<((*b_b)&31));
	unsigned int bind_c = (*b_c)>>10;
	unsigned int bval_c = (1<<((*b_c)&31));
	unsigned int bind_d = (*b_d)>>10;
	unsigned int bval_d = (1<<((*b_d)&31));
	bitmaps[bind_a] |=bval_a;
	bitmaps[bind_b+65535*8*8] |=bval_b;
	bitmaps[bind_c+65535*16*8] |=bval_c;
	bitmaps[bind_d+65535*24*8] |=bval_d;
	singlehash.x |= (1<<((*b_b)&31));
	singlehash.y |= (1<<((*b_c)&31));
	singlehash.z |= (1<<((*b_d)&31));
        if (mylist) mylist = mylist->next;
	singlehash.w=0;
	p2.s0=p2.s4=p2.s8=p2.sC=singlehash.x;
	p2.s1=p2.s5=p2.s9=p2.sD=singlehash.y;
	p2.s2=p2.s6=p2.sA=p2.sE=singlehash.z;
	p2.s3=p2.s7=p2.sB=p2.sF=singlehash.z;
    }
   if (a==1)
   {
        mylist = hash_list;
        memcpy(hex1,mylist->hash,8);
        memcpy(&singlehash.x, hex1, 8);
        memcpy(hex1,mylist->hash+8, 8);
        memcpy(&singlehash.y, hex1, 8);
        memcpy(hex1,mylist->hash+16, 8);
        memcpy(&singlehash.z, hex1, 8);
        memcpy(hex1,mylist->hash+24,8);
        memcpy(&singlehash.w, hex1, 8);
        Endian_Reverse64(singlehash.w);
        singlehash.w-=H3;
    }

    // Change for other lens
    hashes  = malloc(hash_ret_len*8*MAXFOUND); 
    hashes_buf = _clCreateBuffer(context[self], CL_MEM_WRITE_ONLY, hash_ret_len*8*MAXFOUND, NULL, &err );
    plains=malloc(16*8*MAXFOUND);
    bzero(plains,16*8*MAXFOUND);
    plains_buf = _clCreateBuffer(context[self], CL_MEM_WRITE_ONLY, 16*8*MAXFOUND, NULL, &err );
    _clEnqueueWriteBuffer(queue, plains_buf, CL_TRUE, 0, 16*8*MAXFOUND, plains, 0, NULL, NULL);
    // Change for other types
    bzero(hashes,hash_ret_len*8*MAXFOUND);
    _clEnqueueWriteBuffer(queue, hashes_buf, CL_TRUE, 0, hash_ret_len*8*MAXFOUND, hashes, 0, NULL, NULL);
    found_buf = _clCreateBuffer(context[self], CL_MEM_READ_WRITE, 4, NULL, &err );
    table_buf = _clCreateBuffer(context[self], CL_MEM_READ_ONLY|CL_MEM_USE_HOST_PTR, 128*128*4,table , &err );
    bitmaps_buf = _clCreateBuffer(context[self], CL_MEM_READ_ONLY|CL_MEM_USE_HOST_PTR, 256*256*32*8*4, bitmaps, &err );
    found = 0;
    _clEnqueueWriteBuffer(queue, found_buf, CL_TRUE, 0, 4, &found, 0, NULL, NULL);

    _clSetKernelArg(kernel, 0, sizeof(cl_mem), (void*) &hashes_buf);
    _clSetKernelArg(kernel, 1, sizeof(cl_uint), (void*) &csize);
    _clSetKernelArg(kernel, 2, sizeof(cl_mem), (void*) &plains_buf);
    _clSetKernelArg(kernel, 3, sizeof(cl_mem), (void*) &bitmaps_buf);
    _clSetKernelArg(kernel, 4, sizeof(cl_mem), (void*) &found_buf);
    _clSetKernelArg(kernel, 5, sizeof(cl_mem), (void*) &table_buf);


    global_work_size[0] = (charset_size*charset_size);
    global_work_size[1] = (charset_size*charset_size);
    while ((global_work_size[0] %  local_work_size[0])!=0) global_work_size[0]++;
    while ((global_work_size[1] % (wthreads[self].vectorsize))!=0) global_work_size[1]++;
    global_work_size[1] = global_work_size[1]/wthreads[self].vectorsize;
    image.x=image.y=image.z=image.w=0;
    pthread_mutex_unlock(&biglock); 



    /* markov, len=4 */

    csize=4<<3;
    _clSetKernelArg(kernel, 1, sizeof(uint), (void*) &csize);
    pthread_mutex_lock(&wthreads[self].tempmutex);
    pthread_mutex_unlock(&wthreads[self].tempmutex);
    if (attack_over!=0) goto out;
    image.x=0;image.y=0x80;image.z=0;image.w=0;
    ocl_set_params(try,image,singlehash,&p1,&p2);

    _clSetKernelArg(kernel, 6, sizeof(cl_ulong16), (void*) &p1);
    _clSetKernelArg(kernel, 7, sizeof(cl_ulong16), (void*) &p2);
    try=0;
    ocl_execute(queue, kernel, global_work_size, local_work_size, charset_size, found_buf, hashes_buf, plains_buf, plains, hashes, self, &p1,&p2);
    if (markov_max_len==4) goto out;
    if ((session_restore_flag==0)&&(self==0)) scheduler.len=5;


    /* markov, len=5 */

    csize=5<<3;    sched_wait(5);
    _clSetKernelArg(kernel, 1, sizeof(uint), (void*) &csize);
    if (sched_len()==5)
    if (markov_max_len>=5)
    while ((sched_len()==5)&&((a1=sched_s1())<sched_e1()))
    {
        pthread_mutex_lock(&wthreads[self].tempmutex);
        pthread_mutex_unlock(&wthreads[self].tempmutex);
	if (attack_over!=0) goto out;

    	image.x=0;
        image.y=reduced_charset[a1]|(0x80<<8);
        image.z=0;image.w=0;
    	ocl_set_params(try,image,singlehash,&p1,&p2);

	try++;
	if (try==wthreads[self].loops)
	{
	    ocl_execute(queue, kernel, global_work_size, local_work_size, charset_size, found_buf, hashes_buf, plains_buf, plains, hashes, self, &p1,&p2);
	    try=0;
	}
    }
    ocl_execute(queue, kernel, global_work_size, local_work_size, charset_size, found_buf, hashes_buf, plains_buf, plains, hashes, self, &p1,&p2);


    /* markov, len=6 */
    csize=6<<3;
    sched_wait(6);
    _clSetKernelArg(kernel, 1, sizeof(uint), (void*) &csize);
    if (sched_len()==6)
    if (markov_max_len>=6)
    for (a1=0;a1<reduced_size;a1++)
    while ((sched_len()==6)&&((a2=sched_s2(a1))<sched_e2(a1)))
    if (markov2[a1][a2]>markov_threshold)
    {
        pthread_mutex_lock(&wthreads[self].tempmutex);
        pthread_mutex_unlock(&wthreads[self].tempmutex);
	if (attack_over!=0) goto out;

    	image.x=0;
    	image.y=reduced_charset[a1]|(markov_charset[a2]<<8)|(0x80<<16);
    	image.z=0;image.w=0;
    	ocl_set_params(try,image,singlehash,&p1,&p2);

	try++;
	if (try==wthreads[self].loops)
	{
	    ocl_execute(queue, kernel, global_work_size, local_work_size, charset_size, found_buf, hashes_buf, plains_buf, plains, hashes, self, &p1,&p2);
	    try=0;
	}
    }
    ocl_execute(queue, kernel, global_work_size, local_work_size, charset_size, found_buf, hashes_buf, plains_buf, plains, hashes, self, &p1,&p2);



    /* markov, len=7 */

    csize=7<<3;
    sched_wait(7);
    _clSetKernelArg(kernel, 1, sizeof(uint), (void*) &csize);
    if (sched_len()==7)
    if (markov_max_len>=7)
    for (a1=0;a1<reduced_size;a1++)
    for (a2=0;a2<charset_size;a2++)
    while ((sched_len()==7)&&((a3=sched_s3(a1,a2))<sched_e3(a1,a2)))
    if (markov2[a1][a2]>markov_threshold)
    if (markov1[a2][a3]>markov_threshold)
    {
        pthread_mutex_lock(&wthreads[self].tempmutex);
        pthread_mutex_unlock(&wthreads[self].tempmutex);
	if (attack_over!=0) goto out;

    	image.x=0;
    	image.y=reduced_charset[a1]|(markov_charset[a2]<<8)|(markov_charset[a3]<<16)|(0x80<<24);
    	image.z=0;image.w=0;
    	ocl_set_params(try,image,singlehash,&p1,&p2);

	try++;
	if (try==wthreads[self].loops)
	{
	    ocl_execute(queue, kernel, global_work_size, local_work_size, charset_size, found_buf, hashes_buf, plains_buf, plains, hashes, self, &p1,&p2);
	    try=0;
	}
    }
    ocl_execute(queue, kernel, global_work_size, local_work_size, charset_size, found_buf, hashes_buf, plains_buf, plains, hashes, self, &p1,&p2);



    /* markov, len=8 */

    csize=8<<3;
    sched_wait(8);
    _clSetKernelArg(kernel, 1, sizeof(uint), (void*) &csize);
    if (sched_len()==8)
    if (markov_max_len>=8)
    for (a1=0;a1<reduced_size;a1++)
    for (a2=0;a2<charset_size;a2++)
    while ((sched_len()==8)&&((a3=sched_s3(a1,a2))<sched_e3(a1,a2)))
    if (markov2[a1][a2]>markov_threshold)
    if (markov1[a2][a3]>markov_threshold)
    for (a4=0;a4<charset_size;a4++) 
    if (markov1[a3][a4]>markov_threshold)
    {
        pthread_mutex_lock(&wthreads[self].tempmutex);
        pthread_mutex_unlock(&wthreads[self].tempmutex);
	if (attack_over!=0) goto out;

    	image.x=0;
    	image.y=reduced_charset[a1]|(markov_charset[a2]<<8)|(markov_charset[a3]<<16)|(markov_charset[a4]<<24);
    	image.z=0x80;
    	image.w=0;
    	ocl_set_params(try,image,singlehash,&p1,&p2);

	try++;
	if (try==wthreads[self].loops)
	{
	    ocl_execute(queue, kernel, global_work_size, local_work_size, charset_size, found_buf, hashes_buf, plains_buf, plains, hashes, self, &p1,&p2);
	    try=0;
	}
    }
    ocl_execute(queue, kernel, global_work_size, local_work_size, charset_size, found_buf, hashes_buf, plains_buf, plains, hashes, self, &p1,&p2);


    /* markov, len=9 */
    csize=9<<3;
    sched_wait(9);
    _clSetKernelArg(kernel, 1, sizeof(uint), (void*) &csize);
    if (sched_len()==9)
    if (markov_max_len>=9)
    for (a1=0;a1<reduced_size;a1++)
    for (a2=0;a2<charset_size;a2++)
    while ((sched_len()==9)&&((a3=sched_s3(a1,a2))<sched_e3(a1,a2)))
    if (markov2[a1][a2]>markov_threshold)
    if (markov1[a2][a3]>markov_threshold)
    for (a4=0;a4<charset_size;a4++) 
    if (markov1[a3][a4]>markov_threshold)
    for (a5=0;a5<charset_size;a5++) 
    if (markov1[a4][a5]>markov_threshold)
    {
        pthread_mutex_lock(&wthreads[self].tempmutex);
        pthread_mutex_unlock(&wthreads[self].tempmutex);
	if (attack_over!=0) goto out;

    	image.x=0;
    	image.y=reduced_charset[a1]|(markov_charset[a2]<<8)|(markov_charset[a3]<<16)|(markov_charset[a4]<<24);
    	image.z=(markov_charset[a5])|(0x80<<8);
    	image.w=0;
    	ocl_set_params(try,image,singlehash,&p1,&p2);

	try++;
	if (try==wthreads[self].loops)
	{
	    ocl_execute(queue, kernel, global_work_size, local_work_size, charset_size, found_buf, hashes_buf, plains_buf, plains, hashes, self, &p1,&p2);
	    try=0;
	}
    }
    ocl_execute(queue, kernel, global_work_size, local_work_size, charset_size, found_buf, hashes_buf, plains_buf, plains, hashes, self, &p1,&p2);


    /* markov, len=10 */

    csize=10<<3;
    sched_wait(10);
    _clSetKernelArg(kernel, 1, sizeof(uint), (void*) &csize);
    if (sched_len()==10)
    if (markov_max_len>=10)
    for (a1=0;a1<reduced_size;a1++)
    for (a2=0;a2<charset_size;a2++)
    while ((sched_len()==10)&&((a3=sched_s3(a1,a2))<sched_e3(a1,a2)))
    if (markov2[a1][a2]>markov_threshold)
    if (markov1[a2][a3]>markov_threshold)
    for (a4=0;a4<charset_size;a4++) 
    if (markov1[a3][a4]>markov_threshold)
    for (a5=0;a5<charset_size;a5++) 
    if (markov1[a4][a5]>markov_threshold)
    for (a6=0;a6<charset_size;a6++) 
    if (markov1[a5][a6]>markov_threshold)
    {
        pthread_mutex_lock(&wthreads[self].tempmutex);
        pthread_mutex_unlock(&wthreads[self].tempmutex);
	if (attack_over!=0) goto out;

    	image.x=0;
    	image.y=reduced_charset[a1]|(markov_charset[a2]<<8)|(markov_charset[a3]<<16)|(markov_charset[a4]<<24);
    	image.z=(markov_charset[a5])|(markov_charset[a6]<<8)|(0x80<<16);
    	image.w=0;
    	ocl_set_params(try,image,singlehash,&p1,&p2);

	try++;
	if (try==wthreads[self].loops)
	{
	    ocl_execute(queue, kernel, global_work_size, local_work_size, charset_size, found_buf, hashes_buf, plains_buf, plains, hashes, self, &p1,&p2);
	    try=0;
	}
    }
    ocl_execute(queue, kernel, global_work_size, local_work_size, charset_size, found_buf, hashes_buf, plains_buf, plains, hashes, self, &p1,&p2);


    /* markov, len=11 */

    csize=11<3;
    sched_wait(11);
    _clSetKernelArg(kernel, 1, sizeof(uint), (void*) &csize);
    if (sched_len()==11)
    if (markov_max_len>=11)
    for (a1=0;a1<reduced_size;a1++)
    for (a2=0;a2<charset_size;a2++)
    while ((sched_len()==11)&&((a3=sched_s3(a1,a2))<sched_e3(a1,a2)))
    if (markov2[a1][a2]>markov_threshold)
    if (markov1[a2][a3]>markov_threshold)
    for (a4=0;a4<charset_size;a4++) 
    if (markov1[a3][a4]>markov_threshold)
    for (a5=0;a5<charset_size;a5++) 
    if (markov1[a4][a5]>markov_threshold)
    for (a6=0;a6<charset_size;a6++) 
    if (markov1[a5][a6]>markov_threshold)
    for (a7=0;a7<charset_size;a7++)
    if (markov1[a6][a7]>markov_threshold)
    {
        pthread_mutex_lock(&wthreads[self].tempmutex);
        pthread_mutex_unlock(&wthreads[self].tempmutex);
	if (attack_over!=0) goto out;

    	image.x=0;
    	image.y=reduced_charset[a1]|(markov_charset[a2]<<8)|(markov_charset[a3]<<16)|(markov_charset[a4]<<24);
    	image.z=(markov_charset[a5])|(markov_charset[a6]<<8)|(markov_charset[a7]<<16)|(0x80<<24);
    	image.w=0;
    	ocl_set_params(try,image,singlehash,&p1,&p2);

	try++;
	if (try==wthreads[self].loops)
	{
	    ocl_execute(queue, kernel, global_work_size, local_work_size, charset_size, found_buf, hashes_buf, plains_buf, plains, hashes, self, &p1,&p2);
	    try=0;
	}
    }
    ocl_execute(queue, kernel, global_work_size, local_work_size, charset_size, found_buf, hashes_buf, plains_buf, plains, hashes, self, &p1,&p2);


    /* markov, len=12 */

    csize=12<<3;
    sched_wait(12);
    if (sched_len()==12)
    if (markov_max_len>=12)
    for (a1=0;a1<reduced_size;a1++)
    for (a2=0;a2<charset_size;a2++)
    while ((sched_len()==12)&&((a3=sched_s3(a1,a2))<sched_e3(a1,a2)))
    if (markov2[a1][a2]>markov_threshold)
    if (markov1[a2][a3]>markov_threshold)
    for (a4=0;a4<charset_size;a4++) 
    if (markov1[a3][a4]>markov_threshold)
    for (a5=0;a5<charset_size;a5++) 
    if (markov1[a4][a5]>markov_threshold)
    for (a6=0;a6<charset_size;a6++) 
    if (markov1[a5][a6]>markov_threshold)
    for (a7=0;a7<charset_size;a7++)
    if (markov1[a6][a7]>markov_threshold)
    for (a8=0;a8<charset_size;a8++) 
    if (markov1[a7][a8]>markov_threshold)
    {
        pthread_mutex_lock(&wthreads[self].tempmutex);
        pthread_mutex_unlock(&wthreads[self].tempmutex);
	if (attack_over!=0) goto out;

    	image.x=0;
    	image.y=reduced_charset[a1]|(markov_charset[a2]<<8)|(markov_charset[a3]<<16)|(markov_charset[a4]<<24);
    	image.z=(markov_charset[a5])|(markov_charset[a6]<<8)|(markov_charset[a7]<<16)|(markov_charset[a8]<<24);
    	image.w=0x80;
    	image.z=image.z|(image.w<<32);
    	ocl_set_params(try,image,singlehash,&p1,&p2);

	try++;
	if (try==wthreads[self].loops)
	{
	    ocl_execute(queue, kernel, global_work_size, local_work_size, charset_size, found_buf, hashes_buf, plains_buf, plains, hashes, self, &p1,&p2);
	    try=0;
	}
    }
    ocl_execute(queue, kernel, global_work_size, local_work_size, charset_size, found_buf, hashes_buf, plains_buf, plains, hashes, self, &p1,&p2);

    out:
    free(hashes);
    free(plains);
    return hash_ok;
}



/* Crack callback */
static void ocl_sha512_crack_callback(char *line, int self)
{
    int a,b,c,e;
    int *found;
    int err;
    struct  hash_list_s  *mylist, *addlist;
    char plain[MAX];

    if (ocl_rule_opt_counts[self]==0)
    {
        bzero(&addline1[self],sizeof(cl_ulong16));
    }
    strcpy(addlines[self][ocl_rule_opt_counts[self]],line);
    switch (ocl_rule_opt_counts[self])
    {
        case 0:
            addline1[self].sC=strlen(line);
            addline1[self].s0=line[0]|(line[1]<<8)|(line[2]<<16)|(line[3]<<24);
            addline1[self].s1=line[4]|(line[5]<<8)|(line[6]<<16)|(line[7]<<24);
            addline1[self].s2=line[8]|(line[9]<<8)|(line[10]<<16)|(line[11]<<24);
            addline1[self].s3=line[12]|(line[13]<<8)|(line[14]<<16)|(line[15]<<24);
	    break;
        case 1:
            addline1[self].sD=strlen(line);
            addline1[self].s4=line[0]|(line[1]<<8)|(line[2]<<16)|(line[3]<<24);
    	    addline1[self].s5=line[4]|(line[5]<<8)|(line[6]<<16)|(line[7]<<24);
            addline1[self].s6=line[8]|(line[9]<<8)|(line[10]<<16)|(line[11]<<24);
    	    break;
    }


    if (attack_over!=0) pthread_exit(NULL);
    pthread_mutex_lock(&wthreads[self].tempmutex);
    pthread_mutex_unlock(&wthreads[self].tempmutex);

    ocl_rule_opt_counts[self]++;
    if ((line[0]==0)||(ocl_rule_opt_counts[self]>=wthreads[self].vectorsize))
    {
        wthreads[self].tries+=ocl_rule_workset[self]*ocl_rule_opt_counts[self];
        _clSetKernelArg(rule_kernel[self], 7, sizeof(cl_uint16), (void*) &addline1[self]);
        _clEnqueueNDRangeKernel(rule_oclqueue[self], rule_kernel[self], 1, NULL, &ocl_rule_workset[self], rule_local_work_size, 0, NULL, NULL);
        found = _clEnqueueMapBuffer(rule_oclqueue[self], rule_found_buf[self], CL_TRUE,CL_MAP_READ, 0, 4, 0, 0, NULL, &err);
        if (*found>0) 
        {
            _clEnqueueReadBuffer(rule_oclqueue[self], rule_found_ind_buf[self], CL_TRUE, 0, ocl_rule_workset[self]*sizeof(cl_uint), rule_found_ind[self], 0, NULL, NULL);
            for (a=0;a<ocl_rule_workset[self];a++)
            if (rule_found_ind[self][a]==1)
            {
                b=a*wthreads[self].vectorsize;
                _clEnqueueReadBuffer(rule_oclqueue[self], rule_buffer[self], CL_TRUE, b*hash_ret_len, hash_ret_len*wthreads[self].vectorsize, rule_ptr[self]+b*hash_ret_len, 0, NULL, NULL);
                for (c=0;c<wthreads[self].vectorsize;c++)
                {
                    e=(a)*wthreads[self].vectorsize+c;
                    if (hash_index[rule_ptr[self][e*hash_ret_len]&255][rule_ptr[self][e*hash_ret_len+1]&255].nodes)
                    {
                        mylist = hash_index[rule_ptr[self][e*hash_ret_len]&255][rule_ptr[self][e*hash_ret_len+1]&255].nodes;
                        while (mylist)
                        {
                            if (memcmp(mylist->hash, (char *)rule_ptr[self]+(e)*hash_ret_len, hash_ret_len) == 0)
                            {
                                int flag = 0;
                                strcpy(plain,&rule_images[self][0]+(a*MAX));
                                strcat(plain,addlines[self][c]);
                                pthread_mutex_lock(&crackedmutex);
                                addlist = cracked_list;
                                while (addlist)
                                {
                                    if ( (strcmp(addlist->username, mylist->username) == 0) && (memcmp(addlist->hash, mylist->hash, hash_ret_len) == 0))
                                    flag = 1;
                                    addlist = addlist->next;
                                }
                                pthread_mutex_unlock(&crackedmutex);
                                if (flag == 0)
                                {
                                    add_cracked_list(mylist->username, mylist->hash, mylist->salt, plain);
                                }
                            }
                            mylist = mylist->indexnext;
                        }
                    }
                }
            }
            bzero(rule_found_ind[self],ocl_rule_workset[self]*sizeof(cl_uint));
            _clEnqueueWriteBuffer(rule_oclqueue[self], rule_found_ind_buf[self], CL_FALSE, 0, ocl_rule_workset[self]*sizeof(cl_uint), rule_found_ind[self], 0, NULL, NULL);
            *found = 0;
            _clEnqueueWriteBuffer(rule_oclqueue[self], rule_found_buf[self], CL_FALSE, 0, 4, found, 0, NULL, NULL);
        }
        _clEnqueueUnmapMemObject(rule_oclqueue[self],rule_found_buf[self],(void *)found,0,NULL,NULL);
        if (attack_over!=0) pthread_exit(NULL);
        ocl_rule_opt_counts[self]=0;
    }
}



static void ocl_sha512_callback(char *line, int self)
{
    if ((rule_counts[self][0]==-1)&&(line[0]==0x01)) return;
    rule_counts[self][0]++;
    rule_sizes[self][rule_counts[self][0]] = strlen(line);
    strcpy(&rule_images[self][0]+(rule_counts[self][0]*MAX),line);
    if ((rule_counts[self][0]>=(ocl_rule_workset[self]-1))||(line[0]==0x01))
    {
	_clEnqueueWriteBuffer(rule_oclqueue[self], rule_images_buf[self], CL_FALSE, 0, ocl_rule_workset[self]*MAX, rule_images[self], 0, NULL, NULL);
	_clEnqueueWriteBuffer(rule_oclqueue[self], rule_sizes_buf[self], CL_FALSE, 0, ocl_rule_workset[self]*sizeof(int), rule_sizes[self], 0, NULL, NULL);
	ocl_rule_opt_counts[self]=0;
	rule_offload_perform(ocl_sha512_crack_callback,self);
    	bzero(&rule_images[self][0],ocl_rule_workset[self]*MAX);
	rule_counts[self][0]=-1;
    }
    if (attack_over==2) pthread_exit(NULL);
}




/* Worker thread - rule attack */
void* ocl_rule_sha512_thread(void *arg)
{
    cl_int err;
    unsigned char hex1[hash_ret_len];
    int a;
    int found;
    struct  hash_list_s  *mylist;
    size_t nvidia_local_work_size[3]={64,1,1};
    size_t amd_local_work_size[3]={64,1,1};
    int self;

    memcpy(&self,arg,sizeof(int));
    pthread_mutex_lock(&biglock);

    if (wthreads[self].type==nv_thread) rule_local_work_size = nvidia_local_work_size;
    else rule_local_work_size = amd_local_work_size;
    ocl_rule_workset[self]=128*128*2;
    if (wthreads[self].ocl_have_gcn) ocl_rule_workset[self]*=2;
    if (ocl_gpu_double) ocl_rule_workset[self]*=2;
    
    rule_ptr[self] = malloc(ocl_rule_workset[self]*hash_ret_len*wthreads[self].vectorsize);
    rule_counts[self][0]=0;
    rule_kernel[self] = _clCreateKernel(program[self], "sha512", &err );
    rule_oclqueue[self] = _clCreateCommandQueue(context[self], wthreads[self].cldeviceid, 0, &err );
    rule_buffer[self] = _clCreateBuffer(context[self], CL_MEM_WRITE_ONLY, ocl_rule_workset[self]*wthreads[self].vectorsize*hash_ret_len, NULL, &err );
    rule_found_buf[self] = _clCreateBuffer(context[self], CL_MEM_WRITE_ONLY, 4, NULL, &err );

    if (!bitmaps) bitmaps = malloc(256*256*32*4*8);
    for (a=0;a<256*256*32*8;a++)
    {
        bitmaps[a]=0;
    }

    mylist = hash_list;
    a=0;
    while (mylist)
    {
        memcpy(hex1,mylist->hash,hash_ret_len);
	a++;
	unsigned int *b_a = (unsigned int *)hex1;
	unsigned int *b_b = (unsigned int *)&hex1[4];
	unsigned int *b_c = (unsigned int *)&hex1[8];
	unsigned int *b_d = (unsigned int *)&hex1[12];
	unsigned int bind_a = (*b_a)>>10;
	unsigned int bval_a = (1<<((*b_a)&31));
	unsigned int bind_b = (*b_b)>>10;
	unsigned int bval_b = (1<<((*b_b)&31));
	unsigned int bind_c = (*b_c)>>10;
	unsigned int bval_c = (1<<((*b_c)&31));
	unsigned int bind_d = (*b_d)>>10;
	unsigned int bval_d = (1<<((*b_d)&31));
	bitmaps[bind_a] |=bval_a;
	bitmaps[bind_b+65535*8*8] |=bval_b;
	bitmaps[bind_c+65535*16*8] |=bval_c;
	bitmaps[bind_d+65535*24*8] |=bval_d;
	rule_singlehash_long[self].x |= (1<<((*b_b)&31));
	rule_singlehash_long[self].y |= (1<<((*b_c)&31));
	rule_singlehash_long[self].z |= (1<<((*b_d)&31));
    	if (mylist) mylist = mylist->next;
    }
    if (a==1)
    {
        mylist = hash_list;
        memcpy(hex1,mylist->hash,8);
        memcpy(&rule_singlehash_long[self].x, hex1, 8);
        memcpy(hex1,mylist->hash+8,8);
        memcpy(&rule_singlehash_long[self].y, hex1, 8);
        memcpy(hex1,mylist->hash+16,8);
        memcpy(&rule_singlehash_long[self].z, hex1, 8);
        memcpy(hex1,mylist->hash+24,8);
        memcpy(&rule_singlehash_long[self].w, hex1, 8);
        _clSetKernelArg(rule_kernel[self], 6, sizeof(cl_ulong4), (void*) &rule_singlehash_long[self]);
    }
    else 
    {
        rule_singlehash_long[self].w=0;
        _clSetKernelArg(rule_kernel[self], 6, sizeof(cl_ulong4), (void*) &rule_singlehash_long[self]);
    }

    rule_found_ind[self]=malloc(ocl_rule_workset[self]*sizeof(cl_uint));
    bzero(rule_found_ind[self],sizeof(uint)*ocl_rule_workset[self]);
    rule_found_ind_buf[self] = _clCreateBuffer(context[self], CL_MEM_WRITE_ONLY, ocl_rule_workset[self]*sizeof(cl_uint), NULL, &err );
    _clEnqueueWriteBuffer(rule_oclqueue[self], rule_found_buf[self], CL_TRUE, 0, 4, &found, 0, NULL, NULL);
    rule_bitmap_buf = _clCreateBuffer(context[self], CL_MEM_READ_ONLY|CL_MEM_USE_HOST_PTR, 256*256*32*4*8, bitmaps, &err );
    rule_images_buf[self] = _clCreateBuffer(context[self], CL_MEM_READ_WRITE, ocl_rule_workset[self]*MAX, NULL, &err );
    rule_sizes_buf[self] = _clCreateBuffer(context[self], CL_MEM_READ_WRITE, ocl_rule_workset[self]*sizeof(cl_int), NULL, &err );
    rule_sizes[self]=malloc(ocl_rule_workset[self]*sizeof(cl_uint));
    rule_images[self]=malloc(ocl_rule_workset[self]*MAX);
    bzero(&rule_images[self][0],ocl_rule_workset[self]*MAX);
    bzero(&rule_images[self][0],ocl_rule_workset[self]*sizeof(cl_uint));
    _clSetKernelArg(rule_kernel[self], 0, sizeof(cl_mem), (void*) &rule_buffer[self]);
    _clSetKernelArg(rule_kernel[self], 1, sizeof(cl_mem), (void*) &rule_images_buf[self]);
    _clSetKernelArg(rule_kernel[self], 2, sizeof(cl_mem), (void*) &rule_sizes_buf[self]);
    _clSetKernelArg(rule_kernel[self], 3, sizeof(cl_mem), (void*) &rule_found_ind_buf[self]);
    _clSetKernelArg(rule_kernel[self], 4, sizeof(cl_mem), (void*) &rule_bitmap_buf);
    _clSetKernelArg(rule_kernel[self], 5, sizeof(cl_mem), (void*) &rule_found_buf[self]);
    pthread_mutex_unlock(&biglock); 

    worker_gen(self,ocl_sha512_callback);

    return hash_ok;
}




hash_stat ocl_bruteforce_sha512(void)
{
    int a,i;
    uint64_t bcnt;
    int err;
    int worker_thread_keys[32];

    bcnt=1;
    bruteforce_start=4;
    for (a=bruteforce_start;a<bruteforce_end;a++) bcnt*=strlen(bruteforce_charset);
    attack_overall_count = bcnt;

    /* setup initial OpenCL vars */
    int numplatforms=0;
    _clGetPlatformIDs(4, platform, (cl_uint *)&numplatforms);

    init_bruteforce_long();
    scheduler_setup(bruteforce_start, 5, bruteforce_end, strlen(bruteforce_charset), strlen(bruteforce_charset));
    for (i=0;i<nwthreads;i++) if (wthreads[i].type!=cpu_thread)
    {
        _clGetDeviceIDs(platform[wthreads[i].platform], CL_DEVICE_TYPE_GPU, 64, device, (cl_uint *)&devicesnum);
    	context[i] = _clCreateContext(NULL, 1, &device[wthreads[i].deviceid], NULL, NULL, &err);

    	if (wthreads[i].type != nv_thread)
    	{
    	    char *binary;
    	    size_t binary_size;
    	    FILE *fp;
    	    char pbuf[100];
    	    bzero(pbuf,100);
    	    char kernelfile[255];
    	    _clGetDeviceInfo(device[wthreads[i].deviceid], CL_DEVICE_NAME, sizeof(pbuf),pbuf, NULL );
    	    if (hash_list->next) 
    	    {
    	        sprintf(kernelfile,"%s/hashkill/kernels/amd_sha512_long__%s.bin",DATADIR,pbuf);
    	    }
    	    else
    	    {
    	        sprintf(kernelfile,"%s/hashkill/kernels/amd_sha512_long_S_%s.bin",DATADIR,pbuf);
	    }

    	    char *ofname = kernel_decompress(kernelfile);
    	    if (!ofname) return hash_err;
    	    fp=fopen(ofname,"r");
    	    if (!fp) 
    	    {
        	elog("Can't open kernel: %s\n",kernelfile);
            	exit(1);
    	    }
    	    fseek(fp, 0, SEEK_END);
    	    binary_size = ftell(fp);
    	    fseek(fp, 0, SEEK_SET);
    	    binary=malloc(binary_size);
    	    fread(binary,binary_size,1,fp);
    	    fclose(fp);
    	    unlink(ofname);
    	    free(ofname);
    	    if (wthreads[i].first==1) hlog("Loading kernel: %s\n",kernelfile);
    	    program[i] = _clCreateProgramWithBinary(context[i], 1, &device[wthreads[i].deviceid], (size_t *)&binary_size, (const unsigned char **)&binary, NULL, &err );
    	    _clBuildProgram(program[i], 1, &device[wthreads[i].deviceid], "", NULL, NULL );
    	    free(binary);
    	}
    	else
    	{
    	    #define CL_DEVICE_COMPUTE_CAPABILITY_MAJOR_NV       0x4000
    	    #define CL_DEVICE_COMPUTE_CAPABILITY_MINOR_NV       0x4001
    	    char *binary;
    	    size_t binary_size;
    	    FILE *fp;
    	    char pbuf[100];
    	    bzero(pbuf,100);
    	    char kernelfile[255];
    	    _clGetDeviceInfo(device[wthreads[i].deviceid], CL_DEVICE_NAME, sizeof(pbuf),pbuf, NULL );
    	    cl_uint compute_capability_major, compute_capability_minor;
    	    _clGetDeviceInfo(device[wthreads[i].deviceid], CL_DEVICE_COMPUTE_CAPABILITY_MAJOR_NV, sizeof(cl_uint), &compute_capability_major, NULL);
    	    _clGetDeviceInfo(device[wthreads[i].deviceid], CL_DEVICE_COMPUTE_CAPABILITY_MINOR_NV, sizeof(cl_uint), &compute_capability_minor, NULL);
    	    if ((compute_capability_major==1)&&(compute_capability_minor==0)) sprintf(pbuf,"sm10");
    	    if ((compute_capability_major==1)&&(compute_capability_minor==1)) sprintf(pbuf,"sm11");
    	    if ((compute_capability_major==1)&&(compute_capability_minor==2)) sprintf(pbuf,"sm12");
    	    if ((compute_capability_major==1)&&(compute_capability_minor==3)) sprintf(pbuf,"sm13");
    	    if ((compute_capability_major==2)&&(compute_capability_minor==0)) sprintf(pbuf,"sm20");
    	    if ((compute_capability_major==2)&&(compute_capability_minor==1)) sprintf(pbuf,"sm21");
	    if ((compute_capability_major==3)&&(compute_capability_minor==0)) sprintf(pbuf,"sm30");
    	    if (hash_list->next) 
    	    {
    	        sprintf(kernelfile,"%s/hashkill/kernels/nvidia_sha512_long__%s.ptx",DATADIR,pbuf);
    	    }
    	    else
    	    {
    	        sprintf(kernelfile,"%s/hashkill/kernels/nvidia_sha512_long_S_%s.ptx",DATADIR,pbuf);
	    }

    	    char *ofname = kernel_decompress(kernelfile);
    	    if (!ofname) return hash_err;
    	    fp=fopen(ofname,"r");
    	    if (!fp) 
    	    {
        	elog("Can't open kernel: %s\n",kernelfile);
            	exit(1);
    	    }

    	    fseek(fp, 0, SEEK_END);
    	    binary_size = ftell(fp);
    	    fseek(fp, 0, SEEK_SET);
    	    binary=malloc(binary_size);
    	    fread(binary,binary_size,1,fp);
    	    fclose(fp);
    	    unlink(ofname);
    	    free(ofname);
    	    if (wthreads[i].first==1) hlog("Loading kernel: %s\n",kernelfile);
    	    program[i] = _clCreateProgramWithBinary(context[i], 1, &device[wthreads[i].deviceid], (size_t *)&binary_size, (const unsigned char **)&binary, NULL, &err );
    	    _clBuildProgram(program[i], 1, &device[wthreads[i].deviceid], NULL, NULL, NULL );
    	    free(binary);
    	}
    }

    pthread_mutex_init(&biglock, NULL);
    for (a=0;a<nwthreads;a++) if (wthreads[a].type!=cpu_thread)
    {
        worker_thread_keys[a]=a;
        pthread_create(&crack_threads[a], NULL, ocl_bruteforce_sha512_thread, &worker_thread_keys[a]);
    }

    for (a=0;a<nwthreads;a++) if (wthreads[a].type!=cpu_thread) pthread_join(crack_threads[a], NULL);

    printf("\n\n");
    hlog("Done!\n%s","");
    deinit_bruteforce;
    attack_over=2;
    return hash_ok;
}



hash_stat ocl_markov_sha512(void)
{
    int a,i;
    int err;
    int worker_thread_keys[32];

    if (fast_markov==1)  hlog("Fast markov attack mode enabled%s\n","");
    init_markov();
    markov_sched_setlimits();
    if (session_restore_flag==0) scheduler_setup(4, 5, markov_max_len, reduced_size, strlen(markov_charset));

    /* setup initial OpenCL vars */
    int numplatforms=0;
    _clGetPlatformIDs(4, platform, (cl_uint *)&numplatforms);

    for (i=0;i<nwthreads;i++) if (wthreads[i].type!=cpu_thread)
    {
	_clGetDeviceIDs(platform[wthreads[i].platform], CL_DEVICE_TYPE_GPU, 64, device, (cl_uint *)&devicesnum);
        context[i] = _clCreateContext(NULL, 1, &device[wthreads[i].deviceid], NULL, NULL, &err);
        if (wthreads[i].type != nv_thread)
        {
            char *binary;
            size_t binary_size;
            FILE *fp;
            char pbuf[100];
            bzero(pbuf,100);
            char kernelfile[255];
            _clGetDeviceInfo(device[wthreads[i].deviceid], CL_DEVICE_NAME, sizeof(pbuf),pbuf, NULL );
            if (hash_list->next) 
            {
        	sprintf(kernelfile,"%s/hashkill/kernels/amd_sha512_long__%s.bin",DATADIR,pbuf);
    	    }
    	    else
    	    {
        	sprintf(kernelfile,"%s/hashkill/kernels/amd_sha512_long_S_%s.bin",DATADIR,pbuf);
	    }

    	    char *ofname = kernel_decompress(kernelfile);
            if (!ofname) return hash_err;
            fp=fopen(ofname,"r");
            if (!fp) 
            {
                elog("Can't open kernel: %s\n",kernelfile);
                exit(1);
            }
            
            fseek(fp, 0, SEEK_END);
            binary_size = ftell(fp);
            fseek(fp, 0, SEEK_SET);
            binary=malloc(binary_size);
            fread(binary,binary_size,1,fp);
            fclose(fp);
            unlink(ofname);
            free(ofname);
            if (wthreads[i].first==1) hlog("Loading kernel: %s\n",kernelfile);
            program[i] = _clCreateProgramWithBinary(context[i], 1, &device[wthreads[i].deviceid], (size_t *)&binary_size, (const unsigned char **)&binary, NULL, &err );
            err = _clBuildProgram(program[i], 1, &device[wthreads[i].deviceid], "", NULL, NULL );
            free(binary);
        }
        else
        {
            #define CL_DEVICE_COMPUTE_CAPABILITY_MAJOR_NV       0x4000
            #define CL_DEVICE_COMPUTE_CAPABILITY_MINOR_NV       0x4001
            char *binary;
            size_t binary_size;
            FILE *fp;
            char pbuf[100];
            bzero(pbuf,100);
            char kernelfile[255];
            _clGetDeviceInfo(device[wthreads[i].deviceid], CL_DEVICE_NAME, sizeof(pbuf),pbuf, NULL );
    	    cl_uint compute_capability_major, compute_capability_minor;
            _clGetDeviceInfo(device[wthreads[i].deviceid], CL_DEVICE_COMPUTE_CAPABILITY_MAJOR_NV, sizeof(cl_uint), &compute_capability_major, NULL);
            _clGetDeviceInfo(device[wthreads[i].deviceid], CL_DEVICE_COMPUTE_CAPABILITY_MINOR_NV, sizeof(cl_uint), &compute_capability_minor, NULL);
            if ((compute_capability_major==1)&&(compute_capability_minor==0)) sprintf(pbuf,"sm10");
            if ((compute_capability_major==1)&&(compute_capability_minor==1)) sprintf(pbuf,"sm11");
            if ((compute_capability_major==1)&&(compute_capability_minor==2)) sprintf(pbuf,"sm12");
            if ((compute_capability_major==1)&&(compute_capability_minor==3)) sprintf(pbuf,"sm13");
            if ((compute_capability_major==2)&&(compute_capability_minor==0)) sprintf(pbuf,"sm20");
            if ((compute_capability_major==2)&&(compute_capability_minor==1)) sprintf(pbuf,"sm21");
	    if ((compute_capability_major==3)&&(compute_capability_minor==0)) sprintf(pbuf,"sm30");
            if (hash_list->next) 
            {
        	sprintf(kernelfile,"%s/hashkill/kernels/nvidia_sha512_long__%s.ptx",DATADIR,pbuf);
    	    }
    	    else
    	    {
        	sprintf(kernelfile,"%s/hashkill/kernels/nvidia_sha512_long_S_%s.ptx",DATADIR,pbuf);
	    }

    	    char *ofname = kernel_decompress(kernelfile);
            if (!ofname) return hash_err;
            fp=fopen(ofname,"r");
            if (!fp) 
            {
                elog("Can't open kernel: %s\n",kernelfile);
                exit(1);
            }
            
            fseek(fp, 0, SEEK_END);
            binary_size = ftell(fp);
            fseek(fp, 0, SEEK_SET);
            binary=malloc(binary_size);
            fread(binary,binary_size,1,fp);
            fclose(fp);
            unlink(ofname);
            free(ofname);
            if (wthreads[i].first==1) hlog("Loading kernel: %s\n",kernelfile);
            program[i] = _clCreateProgramWithBinary(context[i], 1, &device[wthreads[i].deviceid], (size_t *)&binary_size, (const unsigned char **)&binary, NULL, &err );
            _clBuildProgram(program[i], 1, &device[wthreads[i].deviceid], NULL, NULL, NULL );
            free(binary);
        }
    }

    pthread_mutex_init(&biglock, NULL);
    for (a=0;a<nwthreads;a++) if (wthreads[a].type!=cpu_thread)
    {
	worker_thread_keys[a]=a;
	pthread_create(&crack_threads[a], NULL, ocl_markov_sha512_thread, &worker_thread_keys[a]);
    }
    
    for (a=0;a<nwthreads;a++) if (wthreads[a].type!=cpu_thread) 
    {
	pthread_join(crack_threads[a], NULL);
    }
    printf("\n\n");
    hlog("Done!\n%s","");
    deinit_markov;
    attack_over=2;
    return hash_ok;
}





/* Main thread - rule */
hash_stat ocl_rule_sha512(void)
{
    int a,i;
    int err;
    int worker_thread_keys[32];

    /* setup initial OpenCL vars */
    int numplatforms=0;
    _clGetPlatformIDs(4, platform, (cl_uint *)&numplatforms);

    for (i=0;i<nwthreads;i++) if (wthreads[i].type!=cpu_thread)
    {
	_clGetDeviceIDs(platform[wthreads[i].platform], CL_DEVICE_TYPE_GPU, 64, device, (cl_uint *)&devicesnum);
        context[i] = _clCreateContext(NULL, 1, &device[wthreads[i].deviceid], NULL, NULL, &err);
        if (wthreads[i].type != nv_thread)
        {
            char *binary;
            size_t binary_size;
            FILE *fp;
            char pbuf[100];
            bzero(pbuf,100);
            char kernelfile[255];
            _clGetDeviceInfo(device[wthreads[i].deviceid], CL_DEVICE_NAME, sizeof(pbuf),pbuf, NULL );
            if (hash_list->next) 
            {
        	sprintf(kernelfile,"%s/hashkill/kernels/amd_sha512__%s.bin",DATADIR,pbuf);
    	    }
    	    else
    	    {
        	sprintf(kernelfile,"%s/hashkill/kernels/amd_sha512_S_%s.bin",DATADIR,pbuf);
	    }

    	    char *ofname = kernel_decompress(kernelfile);
            if (!ofname) return hash_err;
            fp=fopen(ofname,"r");
            if (!fp) 
            {
                elog("Can't open kernel: %s\n",kernelfile);
                exit(1);
            }
            
            fseek(fp, 0, SEEK_END);
            binary_size = ftell(fp);
            fseek(fp, 0, SEEK_SET);
            binary=malloc(binary_size);
            fread(binary,binary_size,1,fp);
            fclose(fp);
            unlink(ofname);
            free(ofname);
            if (wthreads[i].first==1) hlog("Loading kernel: %s\n",kernelfile);
            program[i] = _clCreateProgramWithBinary(context[i], 1, &device[wthreads[i].deviceid], (size_t *)&binary_size, (const unsigned char **)&binary, NULL, &err );
            _clBuildProgram(program[i], 1, &device[wthreads[i].deviceid], "", NULL, NULL );
            free(binary);
        }
        else
        {
            #define CL_DEVICE_COMPUTE_CAPABILITY_MAJOR_NV       0x4000
            #define CL_DEVICE_COMPUTE_CAPABILITY_MINOR_NV       0x4001
            char *binary;
            size_t binary_size;
            FILE *fp;
            char pbuf[100];
            bzero(pbuf,100);
            char kernelfile[255];
            _clGetDeviceInfo(device[wthreads[i].deviceid], CL_DEVICE_NAME, sizeof(pbuf),pbuf, NULL );
    	    cl_uint compute_capability_major, compute_capability_minor;
            _clGetDeviceInfo(device[wthreads[i].deviceid], CL_DEVICE_COMPUTE_CAPABILITY_MAJOR_NV, sizeof(cl_uint), &compute_capability_major, NULL);
            _clGetDeviceInfo(device[wthreads[i].deviceid], CL_DEVICE_COMPUTE_CAPABILITY_MINOR_NV, sizeof(cl_uint), &compute_capability_minor, NULL);
            if ((compute_capability_major==1)&&(compute_capability_minor==0)) sprintf(pbuf,"sm10");
            if ((compute_capability_major==1)&&(compute_capability_minor==1)) sprintf(pbuf,"sm11");
            if ((compute_capability_major==1)&&(compute_capability_minor==2)) sprintf(pbuf,"sm12");
            if ((compute_capability_major==1)&&(compute_capability_minor==3)) sprintf(pbuf,"sm13");
            if ((compute_capability_major==2)&&(compute_capability_minor==0)) sprintf(pbuf,"sm20");
            if ((compute_capability_major==2)&&(compute_capability_minor==1)) sprintf(pbuf,"sm21");
	    if ((compute_capability_major==3)&&(compute_capability_minor==0)) sprintf(pbuf,"sm30");
            if (hash_list->next) 
            {
        	sprintf(kernelfile,"%s/hashkill/kernels/nvidia_sha512__%s.ptx",DATADIR,pbuf);
    	    }
    	    else
    	    {
        	sprintf(kernelfile,"%s/hashkill/kernels/nvidia_sha512_S_%s.ptx",DATADIR,pbuf);
	    }

    	    char *ofname = kernel_decompress(kernelfile);
            if (!ofname) return hash_err;
            fp=fopen(ofname,"r");
            if (!fp) 
            {
                elog("Can't open kernel: %s\n",kernelfile);
                exit(1);
            }
            
            fseek(fp, 0, SEEK_END);
            binary_size = ftell(fp);
            fseek(fp, 0, SEEK_SET);
            binary=malloc(binary_size);
            fread(binary,binary_size,1,fp);
            fclose(fp);
            unlink(ofname);
            free(ofname);
            if (wthreads[i].first==1) hlog("Loading kernel: %s\n",kernelfile);
            program[i] = _clCreateProgramWithBinary(context[i], 1, &device[wthreads[i].deviceid], (size_t *)&binary_size, (const unsigned char **)&binary, NULL, &err );
            _clBuildProgram(program[i], 1, &device[wthreads[i].deviceid], NULL, NULL, NULL );
            free(binary);
        }
    }


    pthread_mutex_init(&biglock, NULL);

    for (a=0;a<nwthreads;a++)
    {
        worker_thread_keys[a]=a;
        pthread_create(&crack_threads[a], NULL, ocl_rule_sha512_thread, &worker_thread_keys[a]);
    }
    rule_gen_parse(rule_file,ocl_sha512_callback,nwthreads,SELF_THREAD);

    for (a=0;a<nwthreads;a++) pthread_join(crack_threads[a], NULL);
    attack_over=2;
    printf("\n");
    hlog("Done!\n%s","");
    return hash_ok;
}

