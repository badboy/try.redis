# ZADD *key score member*

**TIME COMPLEXITY**:
O(log(N)) with N being the number of elements in the sorted set

**DESCRIPTION**:
Add the specified member having the specifeid score to the sorted set stored at
key. If member is already a member of the sorted set the score is updated, and
the element reinserted in the right position to ensure sorting. If key does not
exist a new sorted set with the specified member as sole member is created. If
the key exists but does not hold a sorted set value an error is returned.

The score value can be the string representation of a double precision floating
point number.

For an introduction to sorted sets check the Introduction to Redis data types
page.

**RETURN VALUE**: Integer reply, specifically:

* 1 if the new element was added
* 0 if the element was already a member of the sorted set and the score was updated
