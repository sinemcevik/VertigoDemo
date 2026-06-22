using UnityEngine;
using UnityEngine.UI;

/// Scrolls a RawImage's UV rect to create an infinite tiling background.
/// - No geometry/layout changes → zero canvas rebuild cost.
/// - Requires: RawImage on the same GameObject; texture Wrap Mode = Repeat.
[RequireComponent(typeof(RawImage))]
public class TiledBackgroundScroller : MonoBehaviour
{
    [SerializeField] private float scrollSpeedX = 0.02f;
    [SerializeField] private float scrollSpeedY = 0f;

    private RawImage _rawImage;
    private Rect _uvRect;

    private void Awake()
    {
        _rawImage = GetComponent<RawImage>();
        _uvRect = _rawImage.uvRect;
    }

    private void Update()
    {
        _uvRect.x = Mathf.Repeat(_uvRect.x + scrollSpeedX * Time.deltaTime, 1f);
        _uvRect.y = Mathf.Repeat(_uvRect.y + scrollSpeedY * Time.deltaTime, 1f);
        _rawImage.uvRect = _uvRect;
    }
}
