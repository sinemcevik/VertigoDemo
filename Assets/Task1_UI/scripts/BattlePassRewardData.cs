using UnityEngine;

[System.Serializable]
public class BattlePassRewardData
{
    public string rewardId;
    public string displayName;

    public RewardType rewardType;
    public RewardTrack track;
    public RewardRarity rarity;

    public Sprite icon;
    public Sprite currencyIcon;

    public int amount;
    public int requiredLevel;

    public bool claimed;
}