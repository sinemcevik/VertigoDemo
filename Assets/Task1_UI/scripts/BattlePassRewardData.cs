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

    [Tooltip("Premium only: when ticked, the next free-track reward for this level is placed at this card's position.")]
    public bool showFreeCard;

    [Tooltip("Background sprite shown on this card when it is locked/unreached (after the progress marker).")]
    public Sprite lockedBackground;
}