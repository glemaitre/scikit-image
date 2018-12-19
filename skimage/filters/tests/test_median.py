import pytest

import numpy as np
from scipy import ndimage

from skimage.filters import median
from skimage.filters import rank
from skimage._shared.testing import assert_allclose


@pytest.fixture
def image():
    return np.array([[1, 2, 3, 2, 1],
                     [1, 1, 2, 2, 3],
                     [3, 2, 1, 2, 1],
                     [3, 2, 1, 1, 1],
                     [1, 2, 1, 2, 3]],
                    dtype=np.uint8)


@pytest.mark.parametrize(
    "mask, shift_x, shift_y, mode, cval, behavior, n_warning, warning_type",
    [(True, None, None, 'nearest', 0.0, 'new', 1, (UserWarning,)),
     (None, 1, None, 'nearest', 0.0, 'new', 1, (UserWarning,)),
     (None, None, 1, 'nearest', 0.0, 'new', 1, (UserWarning,)),
     (True, 1, 1, 'nearest', 0.0, 'new', 1, (UserWarning,)),
     (None, False, False, 'constant', 0.0, 'old', 2, (DeprecationWarning,
                                                      UserWarning,)),
     (None, False, False, 'nearest', 0.0, 'old', 1, (DeprecationWarning,)),
     (None, False, False, 'nearest', 0.0, 'new', 0, [])]
)
def test_median_warning(image, mask, shift_x, shift_y, mode, cval, behavior,
                        n_warning, warning_type):
    if mask:
        mask = np.ones((image.shape), dtype=np.bool_)

    with pytest.warns(None) as records:
        median(image, mask=mask, shift_x=shift_x, shift_y=shift_y, mode=mode,
               behavior=behavior)

    assert len(records) == n_warning
    for rec in records:
        assert isinstance(rec.message, warning_type)


@pytest.mark.parametrize(
    "behavior, func, params",
    [('new', ndimage.median_filter, {'size': (3, 3)}),
     ('old', rank.median, {'selem': np.ones((3, 3), dtype=np.uint8)})]
)
@pytest.mark.filterwarnings("ignore:Default 'behavior' will change")
def test_median_behavior(image, behavior, func, params):
    assert_allclose(median(image, behavior=behavior), func(image, **params))
