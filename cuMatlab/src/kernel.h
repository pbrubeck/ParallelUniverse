/*
 * kernel.h
 *
 *  Created on: May 31, 2016
 *      Author: pbrubeck
 */

#ifndef KERNEL_H_
#define KERNEL_H_


#define MAXTHREADS 512

inline int ceil(int num, int den){
	return (num+den-1)/den;
}
inline dim3 grid(int i){
	return dim3(ceil(i,MAXTHREADS), 1, 1);
}
inline dim3 grid(int i, int j){
	return dim3(ceil(i,MAXTHREADS), j, 1);
}
inline dim3 grid(int i, int j, int k){
	return dim3(ceil(i,MAXTHREADS), j, k);
}

#endif /* KERNEL_H_ */
