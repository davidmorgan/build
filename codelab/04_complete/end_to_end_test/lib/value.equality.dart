part of 'value.dart';
mixin _$Value {
get x;
get y;
bool operator== (other) {
if (other is! Value) return false;
return(other.x == x) && (other.y == y);
}
}
