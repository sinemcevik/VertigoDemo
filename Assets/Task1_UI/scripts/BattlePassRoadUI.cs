using System.Collections.Generic;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

public class BattlePassRoadUI : MonoBehaviour
{
    [Header("Lines")]
    [SerializeField] private RectTransform lockedLine;
    [SerializeField] private RectTransform progressLine;

    [Header("Marker")]
    [SerializeField] private RectTransform playerMarker;

    [Header("Layout")]
    [SerializeField] private float startX = 170f;
    [SerializeField] private float spacingX = 330f;
    [SerializeField] private float roadY = -20f;

    public void Build(int maxLevel, int currentLevel, float xpProgress, Dictionary<int, float> levelCenterX)
    {
        xpProgress = Mathf.Clamp01(xpProgress);
        currentLevel = Mathf.Max(1, currentLevel);

        float firstX = levelCenterX.ContainsKey(1) ? levelCenterX[1] : startX;
        float lastX  = levelCenterX.ContainsKey(maxLevel) ? levelCenterX[maxLevel] : startX + (maxLevel - 1) * spacingX;

        // Road spans symmetrically: firstX of padding before the first milestone
        // and the same amount after the last milestone.
        float roadWidth = lastX + firstX;

        float currentX = levelCenterX.ContainsKey(currentLevel) ? levelCenterX[currentLevel] : firstX;
        float nextX = levelCenterX.ContainsKey(currentLevel + 1)
            ? levelCenterX[currentLevel + 1]
            : Mathf.Min(currentX + spacingX, lastX);
        float markerX = Mathf.Lerp(currentX, nextX, xpProgress);

        // progressLine fills from 0 to markerX + 195; lockedLine picks up exactly where progressLine ends.
        float progressEnd = markerX + 195f;
        progressLine.pivot = new Vector2(0f, 0.5f);
        progressLine.sizeDelta = new Vector2(progressEnd, progressLine.sizeDelta.y);
        progressLine.anchoredPosition = new Vector2(0f, roadY);

        lockedLine.pivot = new Vector2(0f, 0.5f);
        lockedLine.sizeDelta = new Vector2(roadWidth - progressEnd, lockedLine.sizeDelta.y);
        lockedLine.anchoredPosition = new Vector2(progressEnd, roadY);

        playerMarker.pivot = new Vector2(0.5f, 0.5f);
        playerMarker.anchoredPosition = new Vector2(progressEnd, roadY);
    }
}