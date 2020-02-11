/* file: pooling1d_layer_backward_types.h */
/*******************************************************************************
* Copyright 2014-2019 Intel Corporation
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
//  Implementation of backward 1D pooling layer.
//--
*/

#ifndef __POOLING1D_LAYER_BACKWARD_TYPES_H__
#define __POOLING1D_LAYER_BACKWARD_TYPES_H__

#include "algorithms/algorithm.h"
#include "data_management/data/tensor.h"
#include "data_management/data/homogen_tensor.h"
#include "services/daal_defines.h"
#include "algorithms/neural_networks/layers/layer_backward_types.h"
#include "algorithms/neural_networks/layers/pooling1d/pooling1d_layer_types.h"

namespace daal
{
namespace algorithms
{
namespace neural_networks
{
namespace layers
{
namespace pooling1d
{
/**
 * @defgroup pooling1d_backward Backward One-dimensional Pooling Layer
 * \copydoc daal::algorithms::neural_networks::layers::pooling1d::backward
 * @ingroup pooling1d
 * @{
 */
/**
 * \brief Contains classes for backward one-dimensional (1D) pooling layer
 */
namespace backward
{

/**
 * \brief Contains version 1.0 of Intel(R) Data Analytics Acceleration Library (Intel(R) DAAL) interface.
 */
namespace interface1
{
/**
 * <a name="DAAL-CLASS-ALGORITHMS__NEURAL_NETWORKS__LAYERS__POOLING1D__BACKWARD__INPUT"></a>
 * \brief %Input objects for the backward 1D pooling layer
 * \DAAL_DEPRECATED
 */
class DAAL_EXPORT Input : public layers::backward::Input
{
public:
    typedef layers::backward::Input super;
    /**
     * Default constructor
     * \DAAL_DEPRECATED
     */
    DAAL_DEPRECATED Input();

    /**
     * Copy constructor
     * \DAAL_DEPRECATED
     */
    DAAL_DEPRECATED Input(const Input& other);
    /*
     * \DAAL_DEPRECATED
     */
    virtual ~Input() {}

    /**
     * Return the collection with gradient size
     * \return The collection with gradient size
     * \DAAL_DEPRECATED
     */
    DAAL_DEPRECATED_VIRTUAL virtual services::Collection<size_t> getGradientSize() const;

protected:
    /*
     * \DAAL_DEPRECATED
     */
    DAAL_DEPRECATED_VIRTUAL virtual data_management::NumericTablePtr getAuxInputDimensions() const = 0;

    /*
     * \DAAL_DEPRECATED
     */
    DAAL_DEPRECATED_VIRTUAL virtual services::Collection<size_t> getInputGradientSize(const pooling1d::Parameter *parameter) const;

    /*
     * \DAAL_DEPRECATED
     */
    DAAL_DEPRECATED size_t computeInputDimension(size_t maskDim, size_t kernelSize, size_t padding, size_t stride) const;
};

/**
 * <a name="DAAL-CLASS-ALGORITHMS__NEURAL_NETWORKS__LAYERS__POOLING1D__BACKWARD__RESULT"></a>
 * \brief Provides methods to access the result obtained with the compute() method
 *        of the backward 1D pooling layer
 */
class DAAL_EXPORT Result : public layers::backward::Result
{
public:
    /**
     * Default constructor
     * \DAAL_DEPRECATED
     */
    DAAL_DEPRECATED Result();
    /*
     * \DAAL_DEPRECATED
     */
    virtual ~Result() {}

    /**
     * Allocates memory to store the result of the backward 1D pooling layer
     * \param[in] input Pointer to an object containing the input data
     * \param[in] method Computation method for the layer
     * \param[in] parameter %Parameter of the backward 1D pooling layer
     *
     * \return Status of computations
     * \DAAL_DEPRECATED
     */
    template <typename algorithmFPType>
    DAAL_EXPORT services::Status allocate(const daal::algorithms::Input *input, const daal::algorithms::Parameter *parameter, const int method);

    /**
     * Checks the result of the backward 1D pooling layer
     * \param[in] input %Input object for the layer
     * \param[in] parameter %Parameter of the layer
     * \param[in] method Computation method
     *
     * \return Status of computations
     * \DAAL_DEPRECATED
     */
    services::Status check(const daal::algorithms::Input *input, const daal::algorithms::Parameter *parameter, int method) const DAAL_C11_OVERRIDE;
};

} // namespace interface1
using interface1::Input;
using interface1::Result;
} // namespace backward
/** @} */

} // namespace pooling1d
} // namespace layers
} // namespace neural_networks
} // namespace algorithm
} // namespace daal

#endif