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

    [Header("Milestone")]
    [SerializeField] private RectTransform milestoneParent;
    [SerializeField] private GameObject milestonePrefab;

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
        lockedLine.sizeDelta = new Vector2(roadWidth, lockedLine.sizeDelta.y);
        lockedLine.anchoredPosition = new Vector2(roadWidth * 0.5f, roadY);

        float currentX = levelCenterX.ContainsKey(currentLevel) ? levelCenterX[currentLevel] : firstX;
        float nextX = levelCenterX.ContainsKey(currentLevel + 1)
            ? levelCenterX[currentLevel + 1]
            : Mathf.Min(currentX + spacingX, lastX);
        float markerX = Mathf.Lerp(currentX, nextX, xpProgress);

        progressLine.pivot = new Vector2(0f, 0.5f);
        progressLine.sizeDelta = new Vector2(markerX, progressLine.sizeDelta.y);
        progressLine.anchoredPosition = new Vector2(0f, roadY);

        playerMarker.anchoredPosition = new Vector2(markerX, roadY);

        BuildMilestones(maxLevel, currentLevel, levelCenterX);
    }

    private void BuildMilestones(int maxLevel, int currentLevel, Dictionary<int, float> levelCenterX)
    {
        foreach (Transform child in milestoneParent)
            Destroy(child.gameObject);

        for (int level = 1; level <= maxLevel; level++)
        {
            GameObject milestone = Instantiate(milestonePrefab, milestoneParent);
            RectTransform rt = milestone.GetComponent<RectTransform>();

            // Place the checkpoint at the center of this level's reward group.
            float x = levelCenterX.ContainsKey(level)
                ? levelCenterX[level]
                : startX + (level - 1) * spacingX;
            rt.anchoredPosition = new Vector2(x, roadY);

            TMP_Text levelText = milestone.GetComponentInChildren<TMP_Text>();
            if (levelText != null)
                levelText.text = level.ToString();

            Image circle = milestone.GetComponentInChildren<Image>();
            if (circle != null)
            {
                // Completed and current level milestones are gold; future ones are dark.
                bool reached = level <= currentLevel;
                circle.color = reached
                    ? new Color(1f, 0.75f, 0f, 1f)
                    : new Color(0.05f, 0.08f, 0.25f, 1f);
            }
        }
    }
}