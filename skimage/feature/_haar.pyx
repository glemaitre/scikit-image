#cython: cdivision=True
#cython: boundscheck=False
#cython: nonecheck=False
#cython: wraparound=False

from libc.stdlib cimport malloc, free, realloc

import numpy as np

from ..transform import integral_image
from .._shared.transform cimport integrate

FEATURE_TYPE = {'type-2-x': 0, 'type-2-y': 1,
                'type-3-x': 2, 'type-3-y': 3,
                'type-4': 4}



cdef Rectangle** _haar_like_feature_coord(int feature_type, int height,
                                          int width, int* n_rectangle,
                                          int* n_feature) nogil:
    """Private function to compute the coordinates of all Haar-like features.
    """
    # allocate for the worst case scenario
    cdef:
        int max_feature = height ** 2 * width ** 2
        Rectangle** rect_feat = NULL
        int cnt_feat = 0
        int local_n_rectangle = 0
        int x = 0, y = 0, dx = 0, dy = 0

    if feature_type == 0 or feature_type == 1:
        local_n_rectangle = 2
    elif feature_type == 2 or feature_type == 3:
        local_n_rectangle = 3
    else:
        local_n_rectangle = 4
    n_rectangle[0] = local_n_rectangle

    rect_feat = <Rectangle**> malloc(local_n_rectangle * sizeof(Rectangle*))
    for rect_idx in range(local_n_rectangle):
        rect_feat[rect_idx] = <Rectangle*> malloc(max_feature *
                                                  sizeof(Rectangle))

    for y in range(height):
        for x in range(width):
            for dy in range(1, height):
                for dx in range(1, width):
                    # type -> 2 rectangles split along x axis
                    if (feature_type == 0 and
                        (y + dy <= height and x + 2 * dx <= width)):
                        set_rectangle_feature(&rect_feat[0][cnt_feat],
                                              y, x,
                                              y + dy - 1, x + dx - 1)
                        set_rectangle_feature(&rect_feat[1][cnt_feat],
                                              y, x + dx,
                                              y + dy - 1, x + 2 * dx - 1)
                        cnt_feat += 1
                    # type -> 2 rectangles split along y axis
                    elif (feature_type == 1 and
                          (y + 2 * dy <= height and x + dx <= width)):
                        set_rectangle_feature(&rect_feat[0][cnt_feat],
                                              y, x,
                                              y + dy - 1, x + dx - 1)
                        set_rectangle_feature(&rect_feat[1][cnt_feat],
                                              y + dy, x,
                                              y + 2 * dy - 1, x + dx - 1)
                        cnt_feat += 1
                    # type -> 3 rectangles split along x axis
                    elif (feature_type == 2 and
                          (y + dy <= height and x + 3 * dx <= width)):
                        set_rectangle_feature(&rect_feat[0][cnt_feat],
                                              y, x,
                                              y + dy - 1, x + dx - 1)
                        set_rectangle_feature(&rect_feat[1][cnt_feat],
                                              y, x + dx,
                                              y + dy - 1, x + 2 * dx - 1)
                        set_rectangle_feature(&rect_feat[2][cnt_feat],
                                              y, x + 2 * dx,
                                              y + dy - 1, x + 3 * dx - 1)
                        cnt_feat += 1
                    # type -> 3 rectangles split along y axis
                    elif (feature_type == 3 and
                          (y + 3 * dy <= height and x + dx <= width)):
                        set_rectangle_feature(&rect_feat[0][cnt_feat],
                                              y, x,
                                              y + dy - 1, x + dx - 1)
                        set_rectangle_feature(&rect_feat[1][cnt_feat],
                                              y + dy, x,
                                              y + 2 * dy - 1, x + dx - 1)
                        set_rectangle_feature(&rect_feat[2][cnt_feat],
                                              y + 2 * dy, x,
                                              y + 3 * dy - 1, x + dx - 1)
                        cnt_feat += 1
                    # type -> 4 rectangles split along x and y axis
                    elif (feature_type == 4 and
                          (y + 2 * dy <= height and x + 2 * dx <= width)):
                        set_rectangle_feature(&rect_feat[0][cnt_feat],
                                              y, x,
                                              y + dy - 1, x + dx - 1)
                        set_rectangle_feature(&rect_feat[1][cnt_feat],
                                              y, x + dx,
                                              y + dy - 1, x + 2 * dx - 1)
                        set_rectangle_feature(&rect_feat[2][cnt_feat],
                                              y + dy, x,
                                              y + 2 * dy - 1, x + 2 * dx - 1)
                        set_rectangle_feature(&rect_feat[3][cnt_feat],
                                              y + dy, x + dx,
                                              y + 2 * dy - 1, x + 2 * dx - 1)
                        cnt_feat += 1

    for rect_idx in range(local_n_rectangle):
        rect_feat[rect_idx] = <Rectangle*> realloc(
            rect_feat[rect_idx], cnt_feat * sizeof(Rectangle))
    n_feature[0] = cnt_feat

    return rect_feat


cpdef haar_like_feature_coord(feature_type, int height, int width):
    """Compute the coordinates of Haar-like features.

    Parameters
    ----------
    feature_type : string
        The type of feature to consider:

        - 'type-2-x': 2 rectangles varying along the x axis;
        - 'type-2-y': 2 rectangles varying along the y axis;
        - 'type-3-x': 3 rectangles varying along the x axis;
        - 'type-3-y': 3 rectangles varying along the y axis;
        - 'type-4': 4 rectangles varying along x and y axis.

    height : int
        Height of the detection window.

    width : int
        Width of the detection window.

    Returns
    -------
    feature_coord : list of tuple coord, shape (n_rectangles, 2, n_features)
        Coordinates of the rectangles for each feature.

    """
    cdef:
        Rectangle** rect = NULL
        int n_rectangle = 0
        int n_feature = 0
        int i = 0
        int j = 0

    rect = _haar_like_feature_coord(FEATURE_TYPE[feature_type],
                                    height, width, &n_rectangle, &n_feature)

    # allocate the output based on the number of rectangle
    output = [[[], []] for _ in range(n_rectangle)]
    for i in range(n_rectangle):
        for j in range(n_feature):
            output[i][0].append((rect[i][j].top_left.row,
                                 rect[i][j].top_left.col))
            output[i][1].append((rect[i][j].bottom_right.row,
                                 rect[i][j].bottom_right.col))

    return output


cdef integral_floating[:, ::1] _haar_like_feature(
    integral_floating[:, ::1] roi_ii,
    Rectangle** coord,
    int n_rectangle, int n_feature):
    """Private function releasing the GIL to compute the integral for the
    different rectangle."""
    cdef:
        integral_floating[:, ::1] rect_feature = np.zeros(
            (n_rectangle, n_feature), dtype=roi_ii.base.dtype)
        int idx_rect = 0
        int idx_feature = 0

    with nogil:
        for idx_rect in range(n_rectangle):
            for idx_feature in range(n_feature):
                rect_feature[idx_rect, idx_feature] = integrate(
                    roi_ii,
                    coord[idx_rect][idx_feature].top_left.row,
                    coord[idx_rect][idx_feature].top_left.col,
                    coord[idx_rect][idx_feature].bottom_right.row,
                    coord[idx_rect][idx_feature].bottom_right.col)

    return rect_feature


cpdef haar_like_feature(integral_floating[:, ::1] roi_ii, feature_type):
    """Compute the Haar-like features for an integral region of interest.

    Parameters
    ----------
    roi_ii : ndarray
        The region of an image for which the features need to be computed.
        This image need to be an integral image

    feature_type : string
        The type of feature to consider:

        - 'type-2-x': 2 rectangles varying along the x axis;
        - 'type-2-y': 2 rectangles varying along the y axis;
        - 'type-3-x': 3 rectangles varying along the x axis;
        - 'type-3-y': 3 rectangles varying along the y axis;
        - 'type-4': 4 rectangles varying along x and y axis.

    Returns
    -------
    haar_features : ndarray, shape (n_features,)
        Resulting Haar-like features

    """
    cdef:
        Rectangle** coord = NULL
        int n_rectangle = 0
        int n_feature = 0
        int idx_rect = 0
        int idx_feature = 0
        integral_floating[:, ::1] rect_feature

    if feature_type not in FEATURE_TYPE.keys():
        raise ValueError('The given feature type is unknown. Got {}'
                         ' instead of one of {}.'.format(feature_type,
                                                         FEATURE_TYPE))

    # compute all possible coordinates with a specific type of feature
    coord = _haar_like_feature_coord(FEATURE_TYPE[feature_type],
                                     roi_ii.shape[0],
                                     roi_ii.shape[1],
                                     &n_rectangle, &n_feature)

    rect_feature = _haar_like_feature(roi_ii, coord,
                                      n_rectangle, n_feature)

    # deallocate
    for idx_rect in range(n_rectangle):
        free(coord[idx_rect])
    free(coord)

    # the rectangles with odd indices can always be subtracted to the rectangle
    # with even indices
    return (np.sum(rect_feature[1::2], axis=0) -
            np.sum(rect_feature[::2], axis=0))
