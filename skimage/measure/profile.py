import numpy as np
import scipy.ndimage as nd


def profile_line(img, src, dst, linewidth=1,
                 order=0, mode='constant', cval=0.0):
    """Return the intensity profile of an image measured along a scan line.

    Parameters
    ----------
    img : 2d or 3d array
        The image, in grayscale (2d) or multichannel (2d + c) format.
    src : 2-tuple of numeric scalar (float or int)
        The start point of the scan line.
    dst : 2-tuple of numeric scalar (float or int)
        The end point of the scan line.
    linewidth : int, optional
        Width of the scan, perpendicular to the line
    order : int in {0, 1, 2, 3, 4, 5}, optional
        The order of the spline interpolation to compute image values at
        non-integer coordinates. 0 means nearest-neighbor interpolation.
    mode : string, one of {'constant', 'nearest', 'reflect', 'wrap'}, optional
        How to compute any values falling outside of the image.
    cval : float, optional
        If `mode` is 'constant', what constant value to use outside the image.

    Returns
    -------
    return_value : array
        The intensity profile along the scan line. The length of the profile
        is the ceil of the computed length of the scan line.

    Examples
    --------
    >>> x = np.array([[1, 1, 1, 2, 2, 2]])
    >>> img = np.vstack([np.zeros_like(x), x, x, x, np.zeros_like(x)])
    >>> img
    array([[0, 0, 0, 0, 0, 0],
           [1, 1, 1, 2, 2, 2],
           [1, 1, 1, 2, 2, 2],
           [1, 1, 1, 2, 2, 2],
           [0, 0, 0, 0, 0, 0]])
    >>> profile_line(img, (2, 1), (2, 4))
    array([ 1.,  1.,  2.,  2.])

    Notes
    -----
    The destination point is included in the profile, in contrast to
    standard numpy indexing.
    """
    src_row, src_col = src = np.asarray(src, dtype=float)
    dst_row, dst_col = dst = np.asarray(dst, dtype=float)
    d_row, d_col = dst - src
    theta = np.arctan2(d_row, d_col)

    length = np.ceil(np.hypot(d_row, d_col) + 1)
    # we add one above because we include the last point in the profile
    # (in contrast to standard numpy indexing)
    line_col = np.linspace(src_col, dst_col, length)
    line_row = np.linspace(src_row, dst_row, length)

    # we subtract 1 from linewidth to change from pixel-counting
    # (make this line 3 pixels wide) to point distances (the
    # distance between pixel centers)
    col_width = (linewidth - 1) * np.sin(-theta) / 2
    row_width = (linewidth - 1) * np.cos(theta) / 2
    perp_rows = np.array([np.linspace(row_i - row_width, row_i + row_width,
                                      linewidth) for row_i in line_row])
    perp_cols = np.array([np.linspace(col_i - col_width, col_i + col_width,
                                      linewidth) for col_i in line_col])
    perp_lines = np.array([perp_rows, perp_cols])

    if img.ndim == 3:
        pixels = [nd.map_coordinates(img[..., i], perp_lines,
                                     order=order, mode=mode, cval=cval)
                  for i in range(img.shape[2])]
        pixels = np.transpose(np.asarray(pixels), (1, 2, 0))
    else:
        pixels = nd.map_coordinates(img, perp_lines,
                                    order=order, mode=mode, cval=cval)

    intensities = pixels.mean(axis=1)

    return intensities

