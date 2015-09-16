/*
 * Copyright 1993-2015 NVIDIA Corporation.  All rights reserved.
 *
 * Please refer to the NVIDIA end user license agreement (EULA) associated
 * with this source code for terms and conditions that govern your use of
 * this software. Any use, reproduction, disclosure, or distribution of
 * this software and related documentation outside the terms of the EULA
 * is strictly prohibited.
 *
 */

/* Computation of eigenvalues of a small symmetric, tridiagonal matrix */

// includes, system
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <math.h>
#include <float.h>

// includes, project
#include "helper_functions.h"
#include "helper_cuda.h"
#include "config.h"
#include "structs.h"
#include "matlab.h"

// includes, kernels
#include "bisect_kernel_small.cuh"

// includes, file
#include "bisect_small.cuh"

////////////////////////////////////////////////////////////////////////////////
//! Determine eigenvalues for matrices smaller than MAX_SMALL_MATRIX
//! @param TimingIterations  number of iterations for timing
//! @param  input  handles to input data of kernel
//! @param  result handles to result of kernel
//! @param  mat_size  matrix size
//! @param  lg  lower limit of Gerschgorin interval
//! @param  ug  upper limit of Gerschgorin interval
//! @param  precision  desired precision of eigenvalues
//! @param  iterations  number of iterations for timing
////////////////////////////////////////////////////////////////////////////////
void
computeEigenvaluesSmallMatrix(const Tridiag &input, ResultDataSmall &result,
                              const unsigned int mat_size,
                              const double lg, const double ug,
                              const double precision,
                              const unsigned int iterations)
{
    StopWatchInterface *timer = NULL;
    sdkCreateTimer(&timer);
    sdkStartTimer(&timer);

    for (unsigned int i = 0; i < iterations; ++i)
    {

        dim3  blocks(1, 1, 1);
        dim3  threads(MAX_THREADS_BLOCK_SMALL_MATRIX, 1, 1);

        bisectKernel<<< blocks, threads >>>(input.d_a, input.d_b, mat_size,
                                            result.d_left, result.d_right,
                                            result.d_left_count,
                                            result.d_right_count,
                                            lg, ug, 0, mat_size,
                                            precision
                                           );
    }

    checkCudaErrors(cudaDeviceSynchronize());
    sdkStopTimer(&timer);
    getLastCudaError("Kernel launch failed");
    printf("Average time: %f ms (%i iterations)\n",
           sdkGetTimerValue(&timer) / (double) iterations, iterations);

    sdkDeleteTimer(&timer);
}

////////////////////////////////////////////////////////////////////////////////
//! Initialize variables and memory for the result for small matrices
//! @param result  handles to the necessary memory
//! @param  mat_size  matrix_size
////////////////////////////////////////////////////////////////////////////////
void
initResultSmallMatrix(ResultDataSmall &result, const unsigned int mat_size)
{

    result.mat_size_f = sizeof(double) * mat_size;
    result.mat_size_ui = sizeof(unsigned int) * mat_size;

    result.eigenvalues = (double *) malloc(result.mat_size_f);

    // helper variables
    result.zero_f = (double *) malloc(result.mat_size_f);
    result.zero_ui = (unsigned int *) malloc(result.mat_size_ui);

    for (unsigned int i = 0; i < mat_size; ++i)
    {

        result.zero_f[i] = 0.0f;
        result.zero_ui[i] = 0;

        result.eigenvalues[i] = 0.0f;
    }

    checkCudaErrors(cudaMalloc((void **) &result.d_left, result.mat_size_f));
    checkCudaErrors(cudaMalloc((void **) &result.d_right, result.mat_size_f));

    checkCudaErrors(cudaMalloc((void **) &result.d_left_count,
                               result.mat_size_ui));
    checkCudaErrors(cudaMalloc((void **) &result.d_right_count,
                               result.mat_size_ui));

    // initialize result memory
    checkCudaErrors(cudaMemcpy(result.d_left, result.zero_f, result.mat_size_f,
                               cudaMemcpyHostToDevice));
    checkCudaErrors(cudaMemcpy(result.d_right, result.zero_f, result.mat_size_f,
                               cudaMemcpyHostToDevice));
    checkCudaErrors(cudaMemcpy(result.d_right_count, result.zero_ui,
                               result.mat_size_ui,
                               cudaMemcpyHostToDevice));
    checkCudaErrors(cudaMemcpy(result.d_left_count, result.zero_ui,
                               result.mat_size_ui,
                               cudaMemcpyHostToDevice));
}

////////////////////////////////////////////////////////////////////////////////
//! Cleanup memory and variables for result for small matrices
//! @param  result  handle to variables
////////////////////////////////////////////////////////////////////////////////
void
cleanupResultSmallMatrix(ResultDataSmall &result)
{

    freePtr(result.eigenvalues);
    freePtr(result.zero_f);
    freePtr(result.zero_ui);

    checkCudaErrors(cudaFree(result.d_left));
    checkCudaErrors(cudaFree(result.d_right));
    checkCudaErrors(cudaFree(result.d_left_count));
    checkCudaErrors(cudaFree(result.d_right_count));
}

////////////////////////////////////////////////////////////////////////////////
//! Process the result obtained on the device, that is transfer to host and
//! perform basic sanity checking
//! @param  input  handles to input data
//! @param  result  handles to result data
//! @param  mat_size   matrix size
//! @param  filename  output filename
////////////////////////////////////////////////////////////////////////////////
void
processResultSmallMatrix(const Tridiag &input, const ResultDataSmall &result,
                         const unsigned int mat_size,
                         const char *filename)
{

    const unsigned int mat_size_f = sizeof(double) * mat_size;
    const unsigned int mat_size_ui = sizeof(unsigned int) * mat_size;

    // copy data back to host
    double *left = (double *) malloc(mat_size_f);
    unsigned int *left_count = (unsigned int *) malloc(mat_size_ui);

    checkCudaErrors(cudaMemcpy(left, result.d_left, mat_size_f,
                               cudaMemcpyDeviceToHost));
    checkCudaErrors(cudaMemcpy(left_count, result.d_left_count, mat_size_ui,
                               cudaMemcpyDeviceToHost));

    double *eigenvalues = (double *) malloc(mat_size_f);

    for (unsigned int i = 0; i < mat_size; ++i)
    {
        eigenvalues[left_count[i]] = left[i];
    }

    // save result in matlab format
    writeTridiagSymMatlab(filename, input.a, input.b+1, eigenvalues, mat_size);

    freePtr(left);
    freePtr(left_count);
    freePtr(eigenvalues);
}
