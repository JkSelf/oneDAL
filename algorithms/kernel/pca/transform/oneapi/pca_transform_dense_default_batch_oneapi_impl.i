/* file: pca_transform_dense_default_batch_oneapi_impl.i */
/*******************************************************************************
* Copyright 2014-2020 Intel Corporation
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
*     http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*******************************************************************************/

/*
//++
//  Common functions of PCA transformation on GPU
//--
*/

#ifndef __PCA_TRANSFORM_DENSE_DEFAULT_BATCH_ONEAPI_IMPL_I__
#define __PCA_TRANSFORM_DENSE_DEFAULT_BATCH_ONEAPI_IMPL_I__

#include "externals/service_ittnotify.h"
DAAL_ITTNOTIFY_DOMAIN(pca.transform.batch.oneapi);

#include "algorithms/kernel/pca/transform/oneapi/cl_kernels/pca_transform_cl_kernels.cl"

using namespace daal::services;
using namespace daal::oneapi::internal;
using namespace daal::data_management;

namespace daal
{
namespace algorithms
{
namespace pca
{
namespace transform
{
namespace oneapi
{
namespace internal
{
using namespace daal::oneapi::internal;

template <typename algorithmFPType, transform::Method method>
void TransformKernelOneAPI<algorithmFPType, method>::computeTransformedBlock(const uint32_t numRows, const uint32_t numFeatures,
                                                                             const uint32_t numComponents, UniversalBuffer & dataBlock,
                                                                             const services::Buffer<algorithmFPType> & eigenvectors,
                                                                             const services::Buffer<algorithmFPType> & resultBlock)
{
    DAAL_ITTNOTIFY_SCOPED_TASK(pca.transform.compute.gemm);
    BlasGpu<algorithmFPType>::xgemm(math::Layout::ColMajor, math::Transpose::Trans, math::Transpose::NoTrans, numComponents, numRows, numFeatures,
                                    1.0, eigenvectors, numFeatures, 0, dataBlock, numFeatures, 0, 0.0, resultBlock, numComponents, 0);
}

template <typename algorithmFPType, transform::Method method>
services::Status TransformKernelOneAPI<algorithmFPType, method>::computeInvSigmas(ExecutionContextIface & ctx, NumericTable * variances,
                                                                                  const services::Buffer<algorithmFPType> & invSigmas,
                                                                                  const uint32_t numFeatures)
{
    DAAL_ITTNOTIFY_SCOPED_TASK(pca.transform.compute.computeInvSigmas);
    services::Status status;

    ClKernelFactoryIface & factory = ctx.getClKernelFactory();
    buildKernel(ctx, factory);

    const char * const computeInvSigmasKernel = "computeInvSigmas";
    KernelPtr kernel                          = factory.getKernel(computeInvSigmasKernel);
    BlockDescriptor<algorithmFPType> varBlock;
    variances->getBlockOfRows(0, numFeatures, readOnly, varBlock);

    KernelArguments args(2);
    args.set(0, varBlock.getBuffer(), AccessModeIds::read);
    args.set(1, invSigmas, AccessModeIds::write);
    KernelRange range(numFeatures);
    ctx.run(range, kernel, args, &status);
    variances->releaseBlockOfRows(varBlock);
    return status;
}

template <typename algorithmFPType, transform::Method method>
services::Status TransformKernelOneAPI<algorithmFPType, method>::normalize(ExecutionContextIface & ctx, UniversalBuffer & copyBlock,
                                                                           UniversalBuffer & rawMeans, UniversalBuffer & invSigmas, bool hasMeans,
                                                                           bool hasInvSigmas, const uint32_t numFeatures, const uint32_t numVectors)
{
    DAAL_ITTNOTIFY_SCOPED_TASK(pca.transform.compute.normalize);
    services::Status status;

    ClKernelFactoryIface & factory = ctx.getClKernelFactory();
    buildKernel(ctx, factory);

    const char * const normalizeKernel = "normalize";
    KernelPtr kernel                   = factory.getKernel(normalizeKernel);

    const unsigned int workItemsPerGroup = (numFeatures > maxWorkItemsPerGroup) ? maxWorkItemsPerGroup : numFeatures;
    KernelArguments args(7);
    args.set(0, copyBlock, AccessModeIds::readwrite);
    args.set(1, rawMeans, AccessModeIds::read);
    args.set(2, invSigmas, AccessModeIds::read);
    args.set(3, static_cast<unsigned char>(hasMeans));
    args.set(4, static_cast<unsigned char>(hasInvSigmas));
    args.set(5, maxWorkItemsPerGroup);
    args.set(6, numFeatures);

    KernelRange local_range(workItemsPerGroup);
    KernelRange global_range(workItemsPerGroup * numVectors);
    KernelNDRange range(1);
    range.global(global_range, &status);
    DAAL_CHECK_STATUS_VAR(status);
    range.local(local_range, &status);
    DAAL_CHECK_STATUS_VAR(status);

    ctx.run(range, kernel, args, &status);

    return status;
}

template <typename algorithmFPType, transform::Method method>
services::Status TransformKernelOneAPI<algorithmFPType, method>::whitening(ExecutionContextIface & ctx,
                                                                           const services::Buffer<algorithmFPType> & transformedBlock,
                                                                           UniversalBuffer & invEigenvalues, const uint32_t numComponents,
                                                                           const uint32_t numVectors)
{
    DAAL_ITTNOTIFY_SCOPED_TASK(pca.transform.compute.whitening);
    services::Status status;

    ClKernelFactoryIface & factory = ctx.getClKernelFactory();
    buildKernel(ctx, factory);

    const char * const whiteningKernel = "whitening";
    KernelPtr kernel                   = factory.getKernel(whiteningKernel);

    const unsigned int workItemsPerGroup = (numComponents > maxWorkItemsPerGroup) ? maxWorkItemsPerGroup : numComponents;
    KernelArguments args(4);
    args.set(0, transformedBlock, AccessModeIds::readwrite);
    args.set(1, invEigenvalues, AccessModeIds::read);
    args.set(2, maxWorkItemsPerGroup);
    args.set(3, numComponents);

    KernelRange local_range(workItemsPerGroup);
    KernelRange global_range(workItemsPerGroup * numVectors);

    KernelNDRange range(1);
    range.global(global_range, &status);
    DAAL_CHECK_STATUS_VAR(status);
    range.local(local_range, &status);
    DAAL_CHECK_STATUS_VAR(status);

    ctx.run(range, kernel, args, &status);

    return status;
}

template <typename algorithmFPType, transform::Method method>
services::Status TransformKernelOneAPI<algorithmFPType, method>::allocateBuffer(ExecutionContextIface & ctx, UniversalBuffer & returnBuffer,
                                                                                uint32_t bufferSize)
{
    DAAL_ITTNOTIFY_SCOPED_TASK(pca.transform.compute.allocateBuffer);
    services::Status status;

    const algorithmFPType zero = 0.0;
    returnBuffer               = ctx.allocate(TypeIds::id<algorithmFPType>(), bufferSize, &status);
    DAAL_CHECK_STATUS_VAR(status);
    ctx.fill(returnBuffer, zero, &status);

    return status;
}

template <typename algorithmFPType, transform::Method method>
services::Status TransformKernelOneAPI<algorithmFPType, method>::copyBuffer(ExecutionContextIface & ctx, UniversalBuffer & returnBuffer,
                                                                            NumericTable & data, uint32_t nRows, uint32_t nCols)

{
    DAAL_ITTNOTIFY_SCOPED_TASK(pca.transform.compute.copyBuffer);
    services::Status status;

    BlockDescriptor<algorithmFPType> dataBlock;
    DAAL_CHECK_STATUS(status, data.getBlockOfRows(0, nRows, ReadWriteMode::readOnly, dataBlock));

    ctx.copy(returnBuffer, 0, dataBlock.getBuffer(), 0, nRows * nCols, &status);
    data.releaseBlockOfRows(dataBlock);

    return status;
}

template <typename algorithmFPType, transform::Method method>
services::Status TransformKernelOneAPI<algorithmFPType, method>::checkVariances(NumericTable & pVariances, uint32_t numRows)
{
    DAAL_ITTNOTIFY_SCOPED_TASK(pca.transform.compute.checkVariances);
    services::Status status;

    BlockDescriptor<algorithmFPType> varBlock;
    DAAL_CHECK_STATUS(status, pVariances.getBlockOfRows(0, numRows, ReadWriteMode::readOnly, varBlock));
    for (size_t i = 0; i < numRows; i++)
    {
        if (varBlock.getBlockPtr()[i] < 0)
        {
            status |= status.add(ErrorIncorrectOptionalInput);
        }
    }
    pVariances.releaseBlockOfRows(varBlock);

    return status;
}

template <typename algorithmFPType, transform::Method method>
services::Status TransformKernelOneAPI<algorithmFPType, method>::buildKernel(ExecutionContextIface & ctx, ClKernelFactoryIface & factory)
{
    DAAL_ITTNOTIFY_SCOPED_TASK(pca.transform.compute.buildKernel);
    services::Status status;

    auto fptype_name   = oneapi::internal::getKeyFPType<algorithmFPType>();
    auto build_options = fptype_name;

    const services::String options = getKeyFPType<algorithmFPType>();
    services::String cachekey("__daal_algorithms_pca_transform");
    cachekey.add(fptype_name);
    factory.build(ExecutionTargetIds::device, cachekey.c_str(), pca_transform_cl_kernels, build_options.c_str());

    return status;
}

template <typename algorithmFPType, transform::Method method>
services::Status TransformKernelOneAPI<algorithmFPType, method>::initBuffers(ExecutionContextIface & ctx, NumericTable & data,
                                                                             const uint32_t numFeatures, const uint32_t numComponents,
                                                                             const uint32_t numVectors)
{
    services::Status status;

    DAAL_CHECK_STATUS(status, allocateBuffer(ctx, invSigmas, numFeatures));
    DAAL_CHECK_STATUS(status, allocateBuffer(ctx, invEigenvalues, numComponents));
    DAAL_CHECK_STATUS(status, allocateBuffer(ctx, rawMeans, numFeatures));
    copyBlock = ctx.allocate(TypeIds::id<algorithmFPType>(), numVectors * numFeatures, &status);
    copyBuffer(ctx, copyBlock, data, numVectors, numFeatures);

    return status;
}

template <typename algorithmFPType, transform::Method method>
services::Status TransformKernelOneAPI<algorithmFPType, method>::compute(NumericTable & data, NumericTable & eigenvectors, NumericTable * pMeans,
                                                                         NumericTable * pVariances, NumericTable * pEigenvalues,
                                                                         NumericTable & transformedData)
{
    DAAL_ITTNOTIFY_SCOPED_TASK(pca.transform.compute);
    services::Status status;
    ExecutionContextIface & ctx = services::Environment::getInstance()->getDefaultExecutionContext();

    const uint32_t numVectors    = data.getNumberOfRows();
    const uint32_t numFeatures   = data.getNumberOfColumns();
    const uint32_t numComponents = transformedData.getNumberOfColumns();

    initBuffers(ctx, data, numFeatures, numComponents, numVectors);

    bool hasInvSigmas = false;
    if (pVariances != nullptr)
    {
        hasInvSigmas = true;
        DAAL_CHECK_STATUS(status, checkVariances(*pVariances, numFeatures));
        DAAL_CHECK_STATUS(status, computeInvSigmas(ctx, pVariances, invSigmas.template get<algorithmFPType>(), numFeatures));
    }

    if (pEigenvalues != nullptr)
    {
        DAAL_CHECK_STATUS(status, computeInvSigmas(ctx, pEigenvalues, invEigenvalues.template get<algorithmFPType>(), numComponents));
    }

    bool hasMeans = false;
    if (pMeans != nullptr)
    {
        hasMeans = true;
        DAAL_CHECK_STATUS(status, copyBuffer(ctx, rawMeans, *pMeans, numFeatures, 1));
    }

    bool isWhitening = pEigenvalues != nullptr;
    bool isNormalize = pMeans != nullptr || pVariances != nullptr;

    if (isNormalize)
    {
        DAAL_CHECK_STATUS(status, normalize(ctx, copyBlock, rawMeans, invSigmas, hasMeans, hasInvSigmas, numFeatures, numVectors));
    }

    BlockDescriptor<algorithmFPType> transformedBlock;
    DAAL_CHECK_STATUS(status, transformedData.getBlockOfRows(0, transformedData.getNumberOfRows(), ReadWriteMode::readWrite, transformedBlock));

    BlockDescriptor<algorithmFPType> basis;
    DAAL_CHECK_STATUS(status, eigenvectors.getBlockOfRows(0, numComponents, ReadWriteMode::readOnly, basis));

    computeTransformedBlock(numVectors, numFeatures, numComponents, copyBlock, basis.getBuffer(), transformedBlock.getBuffer());

    if (isWhitening)
    {
        DAAL_CHECK_STATUS(status, whitening(ctx, transformedBlock.getBuffer(), invEigenvalues, numComponents, numVectors));
    }
    transformedData.releaseBlockOfRows(transformedBlock);
    eigenvectors.releaseBlockOfRows(basis);

    return status;
}

} /* namespace internal */
} /* namespace oneapi */
} /* namespace transform */
} /* namespace pca */
} /* namespace algorithms */
} /* namespace daal */

#endif
