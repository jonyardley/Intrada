//! Whether the page outline Vision found in a photograph can be trusted enough
//! to flatten the photo to it (#1565). A wrong outline is worse than none: the
//! crop runs and the page comes back skewed, with no banner.

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct Corner {
    pub x: f64,
    pub y: f64,
}

/// Corners are normalised to the frame (0 to 1 on each axis), as Vision
/// reports them. The frame size is the upright pixel buffer Vision was given,
/// not the image's display size: angles measured in normalised space are
/// squashed by the photo's aspect ratio, and a rotated photo transposes it.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct PageOutline {
    pub top_left: Corner,
    pub top_right: Corner,
    pub bottom_left: Corner,
    pub bottom_right: Corner,
    pub frame_width: f64,
    pub frame_height: f64,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum OutlineFault {
    /// The page runs out of the frame, so that side of the outline is the
    /// photo's edge, not the page's.
    CornerOnFrameEdge,
    /// A flat page photographed at any sensible angle keeps opposite edges
    /// within about 16 degrees of parallel (an A4 sheet at 35cm, tilted 25
    /// degrees); a wider skew means the outline took in the surround.
    EdgesNotParallel,
    /// Two corners coincide, so there is no page to flatten to.
    Collapsed,
}

const FRAME_EDGE_MARGIN: f64 = 0.01;
const MAX_OPPOSITE_EDGE_SKEW_DEGREES: f64 = 25.0;
const MIN_EDGE_PIXELS: f64 = 1.0;

pub fn fault(outline: &PageOutline) -> Option<OutlineFault> {
    let corners = [
        outline.top_left,
        outline.top_right,
        outline.bottom_left,
        outline.bottom_right,
    ];
    if corners
        .iter()
        .any(|c| on_frame_edge(c.x) || on_frame_edge(c.y))
    {
        return Some(OutlineFault::CornerOnFrameEdge);
    }

    let edge = |from: Corner, to: Corner| {
        (
            (to.x - from.x) * outline.frame_width,
            (to.y - from.y) * outline.frame_height,
        )
    };
    let left = edge(outline.bottom_left, outline.top_left);
    let right = edge(outline.bottom_right, outline.top_right);
    let top = edge(outline.top_left, outline.top_right);
    let bottom = edge(outline.bottom_left, outline.bottom_right);
    if [left, right, top, bottom]
        .iter()
        .any(|(dx, dy)| dx.hypot(*dy) < MIN_EDGE_PIXELS)
    {
        return Some(OutlineFault::Collapsed);
    }
    if skew_degrees(left, right) > MAX_OPPOSITE_EDGE_SKEW_DEGREES
        || skew_degrees(top, bottom) > MAX_OPPOSITE_EDGE_SKEW_DEGREES
    {
        return Some(OutlineFault::EdgesNotParallel);
    }
    None
}

fn on_frame_edge(value: f64) -> bool {
    !(FRAME_EDGE_MARGIN..=1.0 - FRAME_EDGE_MARGIN).contains(&value)
}

fn skew_degrees(a: (f64, f64), b: (f64, f64)) -> f64 {
    let cross = a.0 * b.1 - a.1 * b.0;
    let dot = a.0 * b.0 + a.1 * b.1;
    cross.atan2(dot).abs().to_degrees()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn corner(x: f64, y: f64) -> Corner {
        Corner { x, y }
    }

    fn outline(tl: (f64, f64), tr: (f64, f64), bl: (f64, f64), br: (f64, f64)) -> PageOutline {
        PageOutline {
            top_left: corner(tl.0, tl.1),
            top_right: corner(tr.0, tr.1),
            bottom_left: corner(bl.0, bl.1),
            bottom_right: corner(br.0, br.1),
            frame_width: 3024.0,
            frame_height: 4032.0,
        }
    }

    #[test]
    fn judges_outlines_from_their_corners() {
        let cases: Vec<(&str, PageOutline, Option<OutlineFault>)> = vec![
            (
                "device log 2026-09-11: spiral book running off the right of the frame",
                outline(
                    (0.0069, 0.7891),
                    (1.0, 0.8125),
                    (0.2292, 0.2461),
                    (1.0, 0.2695),
                ),
                Some(OutlineFault::CornerOnFrameEdge),
            ),
            (
                "the logged lean of 17 degrees alone is within what a tilted camera does",
                outline(
                    (0.05, 0.7891),
                    (0.95, 0.8125),
                    (0.2731, 0.2461),
                    (0.95, 0.2695),
                ),
                None,
            ),
            (
                "left edge leaning 30 degrees against a vertical right edge",
                outline(
                    (0.05, 0.7891),
                    (0.95, 0.8125),
                    (0.468, 0.2461),
                    (0.95, 0.2695),
                ),
                Some(OutlineFault::EdgesNotParallel),
            ),
            (
                "clean page square on",
                outline((0.1, 0.9), (0.9, 0.9), (0.1, 0.1), (0.9, 0.1)),
                None,
            ),
            (
                "A4 sheet at 35cm tilted 20 degrees, pinhole projection, 12.5 degree skew",
                outline(
                    (0.215, 0.7841),
                    (0.785, 0.7841),
                    (0.1182, 0.1195),
                    (0.8818, 0.1195),
                ),
                None,
            ),
            (
                "top edge sloping 34 degrees against a level bottom edge",
                outline((0.1, 0.95), (0.9, 0.55), (0.1, 0.1), (0.9, 0.1)),
                Some(OutlineFault::EdgesNotParallel),
            ),
            (
                "corner just inside the frame margin",
                outline((0.011, 0.9), (0.9, 0.9), (0.011, 0.1), (0.9, 0.1)),
                None,
            ),
            (
                "corner on the frame margin",
                outline((0.009, 0.9), (0.9, 0.9), (0.1, 0.1), (0.9, 0.1)),
                Some(OutlineFault::CornerOnFrameEdge),
            ),
            (
                "corner on the top of the frame",
                outline((0.1, 0.9), (0.9, 0.995), (0.1, 0.1), (0.9, 0.1)),
                Some(OutlineFault::CornerOnFrameEdge),
            ),
            (
                "only the bottom left corner off the left of the frame",
                outline((0.1, 0.9), (0.9, 0.9), (0.005, 0.1), (0.9, 0.1)),
                Some(OutlineFault::CornerOnFrameEdge),
            ),
            (
                "only the bottom right corner off the bottom of the frame",
                outline((0.1, 0.9), (0.9, 0.9), (0.1, 0.1), (0.9, 0.003)),
                Some(OutlineFault::CornerOnFrameEdge),
            ),
            (
                "all four corners on one point",
                outline((0.5, 0.5), (0.5, 0.5), (0.5, 0.5), (0.5, 0.5)),
                Some(OutlineFault::Collapsed),
            ),
        ];
        for (name, outline, expected) in cases {
            assert_eq!(fault(&outline), expected, "{name}");
        }
    }

    #[test]
    fn skew_is_measured_in_pixels_not_normalised_space() {
        let mut keystoned = outline((0.12, 0.9), (0.88, 0.9), (0.05, 0.1), (0.95, 0.1));
        assert_eq!(fault(&keystoned), None);
        keystoned.frame_width = 4032.0;
        keystoned.frame_height = 500.0;
        assert_eq!(fault(&keystoned), Some(OutlineFault::EdgesNotParallel));
    }
}
