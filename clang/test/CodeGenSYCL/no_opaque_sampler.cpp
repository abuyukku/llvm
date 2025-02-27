// RUN: %clang_cc1 -fsycl-is-device -triple spir64-unknown-unknown -disable-llvm-passes -no-opaque-pointers -emit-llvm %s -o - | FileCheck --enable-var-scope %s
// CHECK: define {{.*}}spir_kernel void @{{[a-zA-Z0-9_]+}}(%opencl.sampler_t addrspace(2)* [[SAMPLER_ARG:%[a-zA-Z0-9_]+]])
// CHECK-NEXT: entry:
// CHECK-NEXT: [[SAMPLER_ARG]].addr = alloca %opencl.sampler_t addrspace(2)*, align 8
// CHECK: [[ANON:%[a-zA-Z0-9_]+]] = alloca %class.anon, align 8
// CHECK: [[ANONCAST:%[a-zA-Z0-9_.]+]] = addrspacecast %class.anon* [[ANON]] to %class.anon addrspace(4)*
// CHECK: store %opencl.sampler_t addrspace(2)* [[SAMPLER_ARG]], %opencl.sampler_t addrspace(2)* addrspace(4)* [[SAMPLER_ARG]].addr.ascast, align 8
// CHECK-NEXT: [[BITCAST:%[0-9]+]] = bitcast %class.anon* [[ANON]] to i8*
// CHECK-NEXT: call void @llvm.lifetime.start.p0i8(i64 8, i8* [[BITCAST]]) #4
// CHECK-NEXT: [[GEP:%[a-zA-z0-9]+]]  = getelementptr inbounds %class.anon, %class.anon addrspace(4)* [[ANONCAST]], i32 0, i32 0
// CHECK-NEXT: [[LOAD_SAMPLER_ARG:%[0-9]+]] = load %opencl.sampler_t addrspace(2)*, %opencl.sampler_t addrspace(2)* addrspace(4)* [[SAMPLER_ARG]].addr.ascast, align 8
// CHECK-NEXT: call spir_func void @{{[a-zA-Z0-9_]+}}(%"class.cl::sycl::sampler" addrspace(4)* {{[^,]*}} [[GEP]], %opencl.sampler_t addrspace(2)* [[LOAD_SAMPLER_ARG]])
//

// CHECK: define {{.*}}spir_kernel void @{{[a-zA-Z0-9_]+}}(%opencl.sampler_t addrspace(2)* [[SAMPLER_ARG_WRAPPED:%[a-zA-Z0-9_]+]], i32 noundef [[ARG_A:%[a-zA-Z0-9_]+]])

// Check alloca
// CHECK: [[SAMPLER_ARG_WRAPPED]].addr = alloca %opencl.sampler_t addrspace(2)*, align 8
// CHECK: [[ARG_A]].addr = alloca i32, align 4
// CHECK: [[LAMBDAA:%[a-zA-Z0-9_]+]] = alloca %class.anon.0, align 8
// CHECK: [[LAMBDA:%[a-zA-Z0-9_.]+]] = addrspacecast %class.anon.0* [[LAMBDAA]] to %class.anon.0 addrspace(4)*

// Check argument store
// CHECK: store %opencl.sampler_t addrspace(2)* [[SAMPLER_ARG_WRAPPED]], %opencl.sampler_t addrspace(2)* addrspace(4)* [[SAMPLER_ARG_WRAPPED]].addr.ascast, align 8
// CHECK: store i32 [[ARG_A]], i32 addrspace(4)* [[ARG_A]].addr.ascast, align 4

// Initialize 'a'
// CHECK: [[GEP_LAMBDA:%[a-zA-z0-9]+]] = getelementptr inbounds %class.anon.0, %class.anon.0 addrspace(4)* [[LAMBDA]], i32 0, i32 0
// CHECK: [[GEP_A:%[a-zA-Z0-9]+]] = getelementptr inbounds %struct.sampler_wrapper, %struct.sampler_wrapper addrspace(4)* [[GEP_LAMBDA]], i32 0, i32 1
// CHECK: [[LOAD_A:%[0-9]+]] = load i32, i32 addrspace(4)* [[ARG_A]].addr.ascast, align 4
// CHECK: store i32 [[LOAD_A]], i32 addrspace(4)* [[GEP_A]], align 8

// Initialize wrapped sampler 'smpl'
// CHECK: [[GEP_LAMBDA_0:%[a-zA-z0-9]+]] = getelementptr inbounds %class.anon.0, %class.anon.0 addrspace(4)* [[LAMBDA]], i32 0, i32 0
// CHECK: [[GEP_SMPL:%[a-zA-Z0-9]+]] = getelementptr inbounds %struct.sampler_wrapper, %struct.sampler_wrapper addrspace(4)* [[GEP_LAMBDA_0]], i32 0, i32 0
// CHECK: [[LOAD_SMPL:%[0-9]+]] = load %opencl.sampler_t addrspace(2)*, %opencl.sampler_t addrspace(2)* addrspace(4)* [[SAMPLER_ARG_WRAPPED]].addr.ascast, align 8
// CHECK: call spir_func void @{{[a-zA-Z0-9_]+}}(%"class.cl::sycl::sampler" addrspace(4)* {{.*}}, %opencl.sampler_t addrspace(2)* [[LOAD_SMPL]])
//
#include "Inputs/sycl.hpp"

struct sampler_wrapper {
  cl::sycl::sampler smpl;
  int a;
};

template <typename KernelName, typename KernelType>
__attribute__((sycl_kernel)) void kernel_single_task(const KernelType &kernelFunc) {
  kernelFunc();
}

int main() {
  cl::sycl::sampler smplr;
  kernel_single_task<class first_kernel>([=]() {
    smplr.use();
  });

  sampler_wrapper wrappedSampler = {smplr, 1};
  kernel_single_task<class second_kernel>([=]() {
    wrappedSampler.smpl.use();
  });

  return 0;
}
