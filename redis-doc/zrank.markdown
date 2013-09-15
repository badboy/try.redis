#ZRANK *key member*

**TIME COMPLEXITY**: O(log(N))

**DESCRIPTION**:
Returns the rank of member in the sorted set stored at key, with the scores ordered from low to high.
The rank (or index) is 0-based, which means that the member with the lowest score has rank 0.

**RETURN VALUE**:
If member exists in the sorted set, Integer reply: the rank of member.
If member does not exist in the sorted set or key does not exist, Bulk reply: nil.
