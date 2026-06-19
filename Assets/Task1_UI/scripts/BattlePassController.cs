using System.Collections.Generic;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

public class BattlePassController : MonoBehaviour
{
    [Header("Config")]
    [SerializeField] private BattlePassConfig config;

    [Header("Prefabs")]
    [SerializeField] private RewardNodeUI freeRewardPrefab;
    [SerializeField] private RewardNodeUI premiumRewardPrefab;

    [Header("Parents")]
    [SerializeField] private RectTransform content;
    [SerializeField] private RectTransform freeRewardsParent;
    [SerializeField] private RectTransform premiumRewardsParent;

    [Header("Road")]
    [SerializeField] private BattlePassRoadUI roadUI;
    [SerializeField] private int maxLevel = 10;

    [Header("Layout")]
    [SerializeField] private float startX = 170f;
    [SerializeField] private float spacingX = 330f;

    [Header("Top UI")]
    [SerializeField] private TMP_Text seasonText;
    [SerializeField] private TMP_Text coinText;
    [SerializeField] private TMP_Text diamondText;
    [SerializeField] private TMP_Text xpText;
    [SerializeField] private Image xpFill;
    [SerializeField] private TMP_Text timeLeftText;

    private void Start()
    {
        Build();
    }

    public void Build()
    {
        if (config == null)
        {
            Debug.LogError("BattlePassController: config is not assigned.", this);
            return;
        }

        ClearParent(freeRewardsParent);
        ClearParent(premiumRewardsParent);

        RefreshTopUI();

        Dictionary<int, float> levelCenterX = ComputeLevelCenters();
        BuildRewards(levelCenterX);

        float xpProgress = (float)config.currentXP / config.requiredXP;
        roadUI.Build(maxLevel, config.playerLevel, xpProgress, levelCenterX);
    }

    // Compute the X position of the FIRST premium reward for each level 1..maxLevel.
    // This position doubles as the checkpoint/milestone anchor and the free-reward anchor.
    // Premium reward groups fan out rightward from this position.
    private Dictionary<int, float> ComputeLevelCenters()
    {
        Dictionary<int, List<BattlePassRewardData>> premiumByLevel = GroupByLevel(config.premiumRewards);
        Dictionary<int, float> levelCenterX = new Dictionary<int, float>();
        float curX = startX;

        for (int level = 1; level <= maxLevel; level++)
        {
            int slotCount = premiumByLevel.ContainsKey(level) ? premiumByLevel[level].Count : 1;
            // Checkpoint sits at the first premium reward of this level.
            levelCenterX[level] = curX;
            curX += slotCount * spacingX;
        }

        return levelCenterX;
    }

    private void BuildRewards(Dictionary<int, float> levelCenterX)
    {
        Dictionary<int, List<BattlePassRewardData>> premiumByLevel = GroupByLevel(config.premiumRewards);
        foreach (KeyValuePair<int, List<BattlePassRewardData>> kvp in premiumByLevel)
        {
            // levelCenterX stores the first-reward X; derive the visual group center from it.
            float firstX = levelCenterX.TryGetValue(kvp.Key, out float px)
                ? px
                : startX + Mathf.Max(0, kvp.Key - 1) * spacingX;
            float groupCenterX = firstX + (kvp.Value.Count - 1) * 0.5f * spacingX;
            SpawnRewardGroup(kvp.Value, RewardTrack.Premium, premiumRewardsParent, premiumRewardPrefab, groupCenterX);
        }

        // Free rewards align with their level's checkpoint (= first premium reward X).
        Dictionary<int, List<BattlePassRewardData>> freeByLevel = GroupByLevel(config.freeRewards);
        foreach (KeyValuePair<int, List<BattlePassRewardData>> kvp in freeByLevel)
        {
            float cx = levelCenterX.TryGetValue(kvp.Key, out float px)
                ? px
                : startX + (kvp.Key - 1) * spacingX;
            SpawnRewardGroup(kvp.Value, RewardTrack.Free, freeRewardsParent, freeRewardPrefab, cx);
        }

        // Width: span to the last premium reward in the last level.
        float lastPremiumX = startX;
        if (levelCenterX.ContainsKey(maxLevel))
        {
            int lastCount = premiumByLevel.ContainsKey(maxLevel) ? premiumByLevel[maxLevel].Count : 1;
            lastPremiumX = levelCenterX[maxLevel] + (lastCount - 1) * spacingX;
        }
        float width = lastPremiumX + spacingX * 0.5f + 500f;
        content.sizeDelta = new Vector2(width, content.sizeDelta.y);
    }

    private Dictionary<int, List<BattlePassRewardData>> GroupByLevel(List<BattlePassRewardData> rewards)
    {
        Dictionary<int, List<BattlePassRewardData>> dict = new Dictionary<int, List<BattlePassRewardData>>();
        foreach (BattlePassRewardData reward in rewards)
        {
            if (!dict.ContainsKey(reward.requiredLevel))
                dict[reward.requiredLevel] = new List<BattlePassRewardData>();
            dict[reward.requiredLevel].Add(reward);
        }
        return dict;
    }

    private void SpawnRewardGroup(
        List<BattlePassRewardData> group,
        RewardTrack track,
        RectTransform parent,
        RewardNodeUI prefab,
        float centerX)
    {
        if (prefab == null)
        {
            Debug.LogError($"BattlePassController: prefab for {track} track is not assigned.", this);
            return;
        }

        int n = group.Count;
        for (int i = 0; i < n; i++)
        {
            BattlePassRewardData reward = group[i];
            reward.track = track;

            RewardNodeUI node = Instantiate(prefab, parent);
            RectTransform rt = node.GetComponent<RectTransform>();

            // Each reward occupies one spacingX slot so cards stay on the uniform grid.
            float offset = (i - (n - 1) * 0.5f) * spacingX;
            rt.anchoredPosition = new Vector2(centerX + offset, 0f);

            node.Setup(
                reward,
                config.playerLevel,
                config.premiumOwned,
                OnRewardClaimed
            );
        }
    }

    private void RefreshTopUI()
    {
        if (seasonText != null)
            seasonText.text = config.seasonName.ToUpper();

        if (coinText != null)
            coinText.text = config.coins.ToString();

        if (diamondText != null)
            diamondText.text = config.diamonds.ToString();

        if (xpText != null)
            xpText.text = $"{config.currentXP}/{config.requiredXP}";

        if (xpFill != null)
            xpFill.fillAmount = (float)config.currentXP / config.requiredXP;

        if (timeLeftText != null)
            timeLeftText.text = config.timeLeft;
    }

    private void OnRewardClaimed(BattlePassRewardData reward)
    {
        switch (reward.rewardType)
        {
            case RewardType.Coin:
                config.coins += reward.amount;
                break;

            case RewardType.Diamond:
                config.diamonds += reward.amount;
                break;

            case RewardType.LuckyGem:
                config.luckyGems += reward.amount;
                break;

            case RewardType.Chest:
            case RewardType.Skin:
            case RewardType.Weapon:
            case RewardType.Attachment:
                // Non-currency rewards: no stat to update
                break;
        }

        RefreshTopUI();
    }

    private void ClearParent(RectTransform parent)
    {
        foreach (Transform child in parent)
            Destroy(child.gameObject);
    }
}