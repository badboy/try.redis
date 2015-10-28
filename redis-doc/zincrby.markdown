# ZINCRBY *key increment member*

**TIME COMPLEXITY**:
O(log(N)) with N being the number of elements in the sorted set

**DESCRIPTION**:
If member already exists in the sorted set adds the increment to its score and
updates the position of the element in the sorted set accordingly. If member
does not already exist in the sorted set it is added with increment as score
(that is, like if the previous score was virtually zero). If key does not exist
a new sorted set with the specified member as sole member is created. If the key
exists but does not hold a sorted set value an error is returned.

The score value can be the string representation of a double precision floating
point number. It's possible to provide a negative value to perform a decrement.

For an introduction to sorted sets check the Introduction to Redis data types
page.

**RETURN VALUE**:
Integer reply, specifically:

The score of the member after the increment is performed.
