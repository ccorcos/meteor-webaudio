from pylab import *


# def s(k):
#     f = 1024/(log(float(4410)/k)/log(10))
#     print k, (log(float(440)/k)/log(10))*f
#
# for k in range(300,500):
#     s(k)


# k = 341
# f = 1024/(log(float(4410)/k)/log(10))
#
# def i(v):
#     return (log(float(v)/k)/log(10))*f


print 440, i(440), 102
print 2000, i(2000), 232
print 1000, i(1000), 463
print 3000, i(3000), 595
print 4000, i(4000), 929
print 4300, i(4300), 998

# 440 -> 102
# 1000 -> 232
# 2000 -> 463
# 3000 -> 595
# 4000 -> 929
# 4300 -> 998
