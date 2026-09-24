# core/failure — an error as data and its two renderings (S9.1–S9.5), and the
# serde_json string escaping both renderings and the store share (S5.10).
# Plain mode: `Error: <message>` and an optional `Hint: <hint>` on STDERR.
# JSON mode: a PRETTY-printed `{"error": {...}}` envelope on STDOUT (two-space
# indent, `": "` after a key), with `null` for an absent hint or context, and
# nothing on stderr. Nothing here consults the original.
import Base

# S9.1 (data) one context member's value: a string, a bare literal, or a list of strings
type CtxVal is Data:
  CStr{text: String}
  CBare{text: String}
  CList{items: List<&2, String>}

# S9.1 (data) one context member
type CtxMember is Data:
  CtxMember{key: String, value: CtxVal}

# S9.1 S3.13 (data) the five-member error record plus the process exit code (S9.6)
type Failure is Data:
  Failure{code: String, message: String, hint: Maybe<&2, String>, retryable: Bool, context: List<&2, CtxMember>, exit: U32}

# S5.10 (spec twin) one lower-case hex digit of a control character's \u00XX form
def hex_digit(+n: U32, small: Bool) -> U32:
  match small:
    case True{}:
      (n + 48 : U32)
    case False{}:
      (n + 87 : U32)

# S5.10 (spec twin) a control character below U+0020 pushed, escaped, onto a REVERSED accumulator:
# \b \t \n \f \r where a short form exists, \u00XX with lower-case hex otherwise
def esc_ctl(+c: U32, acc: List<&2, U32>, b: Bool, t: Bool, n: Bool, f: Bool, r: Bool) -> List<&2, U32>:
  match b t n f r:
    case True{} _ _ _ _:
      98 <> (92 <> acc)
    case False{} True{} _ _ _:
      116 <> (92 <> acc)
    case False{} False{} True{} _ _:
      110 <> (92 <> acc)
    case False{} False{} False{} True{} _:
      102 <> (92 <> acc)
    case False{} False{} False{} False{} True{}:
      114 <> (92 <> acc)
    case False{} False{} False{} False{} False{}:
      hex_digit((c .&. 15 : U32), ((c .&. 15 : U32) < 10 : U32)) <> (hex_digit((c >> 4n : U32), True{}) <> (48 <> (48 <> (117 <> (92 <> acc)))))

# S5.10 (spec twin) one code point pushed, escaped, onto a REVERSED accumulator. Only `"`, `\`
# and the controls below U+0020 are escaped: DEL, U+00A0, every non-ASCII scalar, `/`, `<`, `>`, `&` pass raw
def esc_push(+c: U32, acc: List<&2, U32>, quote: Bool, slash: Bool, ctl: Bool) -> List<&2, U32>:
  match quote slash ctl:
    case True{} _ _:
      34 <> (92 <> acc)
    case False{} True{} _:
      92 <> (92 <> acc)
    case False{} False{} True{}:
      esc_ctl(c, acc, U32.is_eq(c, 8), U32.is_eq(c, 9), U32.is_eq(c, 10), U32.is_eq(c, 12), U32.is_eq(c, 13))
    case False{} False{} False{}:
      c <> acc

# S5.10 (spec twin) the loop: the string is the measure, acc is reversed
def esc_go(s: String, acc: List<&2, U32>) -> List<&2, U32>:
  match s:
    case SNil{}:
      acc
    case SCon{Chr{+c}, rest}:
      esc_go(rest, esc_push(c, acc, U32.is_eq(c, 34), U32.is_eq(c, 92), (c < 32 : U32)))

# S5.10 (spec twin) a reversed code-point list as a String, in order
def unreverse(rev: List<&2, U32>, acc: String) -> String:
  match rev:
    case Nil{}:
      acc
    case Con{c, rest}:
      unreverse(rest, SCon{Chr{c}, acc})

# S5.10 (spec twin) a JSON string literal, quotes included
def quoted(s: String) -> String:
  "\"" ++ unreverse(esc_go(s, Nil{}), "\"")

# S4.350 S2.58 (spec twin) the non-ASCII code points Rust's `escape_debug` writes as `\u{…}`, as inclusive ranges
# `lo, hi, lo, hi, …` in ascending order: U+0080–U+00A0, U+00AD, the combining marks, and every code point Rust's
# `is_printable` refuses (unassigned ones included). MEASURED, not typed from Unicode data: the original quoted every
# scalar value U+0001–U+10FFFF on `dep add --metadata "x|c|c|…"` in the sandbox (2026-09-24, OQ-136)
def hidden_table() -> List<&2, U32>:
  [128, 160, 173, 173, 768, 879, 888, 889, 896, 899, 907, 907, 909, 909, 930, 930, 1155, 1161, 1328, 1328, 1367, 1368,
   1419, 1420, 1424, 1469, 1471, 1471, 1473, 1474, 1476, 1477, 1479, 1487, 1515, 1518, 1525, 1541, 1552, 1562, 1564, 1564,
   1611, 1631, 1648, 1648, 1750, 1757, 1759, 1764, 1767, 1768, 1770, 1773, 1806, 1807, 1809, 1809, 1840, 1868, 1958, 1968,
   1970, 1983, 2027, 2035, 2043, 2045, 2070, 2073, 2075, 2083, 2085, 2087, 2089, 2095, 2111, 2111, 2137, 2141, 2143, 2143,
   2155, 2159, 2192, 2207, 2250, 2306, 2362, 2362, 2364, 2364, 2369, 2376, 2381, 2381, 2385, 2391, 2402, 2403, 2433, 2433,
   2436, 2436, 2445, 2446, 2449, 2450, 2473, 2473, 2481, 2481, 2483, 2485, 2490, 2492, 2494, 2494, 2497, 2502, 2505, 2506,
   2509, 2509, 2511, 2523, 2526, 2526, 2530, 2533, 2558, 2562, 2564, 2564, 2571, 2574, 2577, 2578, 2601, 2601, 2609, 2609,
   2612, 2612, 2615, 2615, 2618, 2621, 2625, 2648, 2653, 2653, 2655, 2661, 2672, 2673, 2677, 2677, 2679, 2690, 2692, 2692,
   2702, 2702, 2706, 2706, 2729, 2729, 2737, 2737, 2740, 2740, 2746, 2748, 2753, 2760, 2762, 2762, 2765, 2767, 2769, 2783,
   2786, 2789, 2802, 2808, 2810, 2817, 2820, 2820, 2829, 2830, 2833, 2834, 2857, 2857, 2865, 2865, 2868, 2868, 2874, 2876,
   2878, 2879, 2881, 2886, 2889, 2890, 2893, 2907, 2910, 2910, 2914, 2917, 2936, 2946, 2948, 2948, 2955, 2957, 2961, 2961,
   2966, 2968, 2971, 2971, 2973, 2973, 2976, 2978, 2981, 2983, 2987, 2989, 3002, 3006, 3008, 3008, 3011, 3013, 3017, 3017,
   3021, 3023, 3025, 3045, 3067, 3072, 3076, 3076, 3085, 3085, 3089, 3089, 3113, 3113, 3130, 3132, 3134, 3136, 3141, 3159,
   3163, 3163, 3166, 3167, 3170, 3173, 3184, 3190, 3201, 3201, 3213, 3213, 3217, 3217, 3241, 3241, 3252, 3252, 3258, 3260,
   3263, 3264, 3266, 3266, 3269, 3291, 3295, 3295, 3298, 3301, 3312, 3312, 3316, 3329, 3341, 3341, 3345, 3345, 3387, 3388,
   3390, 3390, 3393, 3397, 3401, 3401, 3405, 3405, 3408, 3411, 3415, 3415, 3426, 3429, 3456, 3457, 3460, 3460, 3479, 3481,
   3506, 3506, 3516, 3516, 3518, 3519, 3527, 3535, 3538, 3543, 3551, 3557, 3568, 3569, 3573, 3584, 3633, 3633, 3636, 3646,
   3655, 3662, 3676, 3712, 3715, 3715, 3717, 3717, 3723, 3723, 3748, 3748, 3750, 3750, 3761, 3761, 3764, 3772, 3774, 3775,
   3781, 3781, 3783, 3791, 3802, 3803, 3808, 3839, 3864, 3865, 3893, 3893, 3895, 3895, 3897, 3897, 3912, 3912, 3949, 3966,
   3968, 3972, 3974, 3975, 3981, 4029, 4038, 4038, 4045, 4045, 4059, 4095, 4141, 4144, 4146, 4151, 4153, 4154, 4157, 4158,
   4184, 4185, 4190, 4192, 4209, 4212, 4226, 4226, 4229, 4230, 4237, 4237, 4253, 4253, 4294, 4294, 4296, 4300, 4302, 4303,
   4447, 4448, 4681, 4681, 4686, 4687, 4695, 4695, 4697, 4697, 4702, 4703, 4745, 4745, 4750, 4751, 4785, 4785, 4790, 4791,
   4799, 4799, 4801, 4801, 4806, 4807, 4823, 4823, 4881, 4881, 4886, 4887, 4955, 4959, 4989, 4991, 5018, 5023, 5110, 5111,
   5118, 5119, 5760, 5760, 5789, 5791, 5881, 5887, 5906, 5918, 5938, 5940, 5943, 5951, 5970, 5983, 5997, 5997, 6001, 6015,
   6068, 6069, 6071, 6077, 6086, 6086, 6089, 6099, 6109, 6111, 6122, 6127, 6138, 6143, 6155, 6159, 6170, 6175, 6265, 6271,
   6277, 6278, 6313, 6313, 6315, 6319, 6390, 6399, 6431, 6434, 6439, 6440, 6444, 6447, 6450, 6450, 6457, 6463, 6465, 6467,
   6510, 6511, 6517, 6527, 6572, 6575, 6602, 6607, 6619, 6621, 6679, 6680, 6683, 6685, 6742, 6742, 6744, 6752, 6754, 6754,
   6757, 6764, 6771, 6783, 6794, 6799, 6810, 6815, 6830, 6915, 6964, 6973, 6978, 6980, 6989, 6989, 7019, 7027, 7040, 7041,
   7074, 7077, 7080, 7085, 7142, 7142, 7144, 7145, 7149, 7149, 7151, 7163, 7212, 7219, 7222, 7226, 7242, 7244, 7307, 7311,
   7355, 7356, 7368, 7378, 7380, 7392, 7394, 7400, 7405, 7405, 7412, 7412, 7416, 7417, 7419, 7423, 7616, 7679, 7958, 7959,
   7966, 7967, 8006, 8007, 8014, 8015, 8024, 8024, 8026, 8026, 8028, 8028, 8030, 8030, 8062, 8063, 8117, 8117, 8133, 8133,
   8148, 8149, 8156, 8156, 8176, 8177, 8181, 8181, 8191, 8207, 8232, 8239, 8287, 8303, 8306, 8307, 8335, 8335, 8349, 8351,
   8386, 8447, 8588, 8591, 9258, 9279, 9291, 9311, 11124, 11125, 11503, 11505, 11508, 11512, 11558, 11558, 11560, 11564, 11566, 11567,
   11624, 11630, 11633, 11647, 11671, 11679, 11687, 11687, 11695, 11695, 11703, 11703, 11711, 11711, 11719, 11719, 11727, 11727, 11735, 11735,
   11743, 11775, 11870, 11903, 11930, 11930, 12020, 12031, 12246, 12271, 12288, 12288, 12330, 12335, 12352, 12352, 12439, 12442, 12544, 12548,
   12592, 12592, 12644, 12644, 12687, 12687, 12774, 12782, 12831, 12831, 42125, 42127, 42183, 42191, 42540, 42559, 42607, 42610, 42612, 42621,
   42654, 42655, 42736, 42737, 42744, 42751, 42973, 42992, 43010, 43010, 43014, 43014, 43019, 43019, 43045, 43046, 43052, 43055, 43066, 43071,
   43128, 43135, 43204, 43213, 43226, 43249, 43263, 43263, 43302, 43309, 43335, 43345, 43347, 43358, 43389, 43394, 43443, 43443, 43446, 43449,
   43452, 43453, 43456, 43456, 43470, 43470, 43482, 43485, 43493, 43493, 43519, 43519, 43561, 43566, 43569, 43570, 43573, 43583, 43587, 43587,
   43596, 43596, 43598, 43599, 43610, 43611, 43644, 43644, 43696, 43696, 43698, 43700, 43703, 43704, 43710, 43711, 43713, 43713, 43715, 43738,
   43756, 43757, 43766, 43776, 43783, 43784, 43791, 43792, 43799, 43807, 43815, 43815, 43823, 43823, 43884, 43887, 44005, 44005, 44008, 44008,
   44013, 44015, 44026, 44031, 55204, 55215, 55239, 55242, 55292, 55295, 57344, 63743, 64110, 64111, 64218, 64255, 64263, 64274, 64280, 64284,
   64286, 64286, 64311, 64311, 64317, 64317, 64319, 64319, 64322, 64322, 64325, 64325, 64976, 65007, 65024, 65039, 65050, 65071, 65107, 65107,
   65127, 65127, 65132, 65135, 65141, 65141, 65277, 65280, 65440, 65440, 65471, 65473, 65480, 65481, 65488, 65489, 65496, 65497, 65501, 65503,
   65511, 65511, 65519, 65531, 65534, 65535, 65548, 65548, 65575, 65575, 65595, 65595, 65598, 65598, 65614, 65615, 65630, 65663, 65787, 65791,
   65795, 65798, 65844, 65846, 65935, 65935, 65949, 65951, 65953, 65999, 66045, 66175, 66205, 66207, 66257, 66272, 66300, 66303, 66340, 66348,
   66379, 66383, 66422, 66431, 66462, 66462, 66500, 66503, 66518, 66559, 66718, 66719, 66730, 66735, 66772, 66775, 66812, 66815, 66856, 66863,
   66916, 66926, 66939, 66939, 66955, 66955, 66963, 66963, 66966, 66966, 66978, 66978, 66994, 66994, 67002, 67002, 67005, 67007, 67060, 67071,
   67383, 67391, 67414, 67423, 67432, 67455, 67462, 67462, 67505, 67505, 67515, 67583, 67590, 67591, 67593, 67593, 67638, 67638, 67641, 67643,
   67645, 67646, 67670, 67670, 67743, 67750, 67760, 67807, 67827, 67827, 67830, 67834, 67868, 67870, 67898, 67902, 67930, 67967, 68024, 68027,
   68048, 68049, 68097, 68111, 68116, 68116, 68120, 68120, 68150, 68159, 68169, 68175, 68185, 68191, 68256, 68287, 68325, 68330, 68343, 68351,
   68406, 68408, 68438, 68439, 68467, 68471, 68498, 68504, 68509, 68520, 68528, 68607, 68681, 68735, 68787, 68799, 68851, 68857, 68900, 68911,
   68922, 68927, 68966, 68973, 68998, 69005, 69008, 69215, 69247, 69247, 69290, 69292, 69294, 69295, 69298, 69313, 69320, 69327, 69337, 69375,
   69416, 69423, 69446, 69456, 69466, 69487, 69506, 69509, 69514, 69551, 69580, 69599, 69623, 69631, 69633, 69633, 69688, 69702, 69710, 69713,
   69744, 69744, 69747, 69748, 69750, 69761, 69811, 69814, 69817, 69818, 69821, 69821, 69826, 69839, 69865, 69871, 69882, 69890, 69927, 69931,
   69933, 69941, 69960, 69967, 70003, 70003, 70007, 70017, 70070, 70078, 70080, 70080, 70089, 70092, 70095, 70095, 70112, 70112, 70133, 70143,
   70162, 70162, 70191, 70193, 70196, 70199, 70206, 70206, 70209, 70271, 70279, 70279, 70281, 70281, 70286, 70286, 70302, 70302, 70314, 70319,
   70367, 70367, 70371, 70383, 70394, 70401, 70404, 70404, 70413, 70414, 70417, 70418, 70441, 70441, 70449, 70449, 70452, 70452, 70458, 70460,
   70462, 70462, 70464, 70464, 70469, 70470, 70473, 70474, 70477, 70479, 70481, 70492, 70500, 70527, 70538, 70538, 70540, 70541, 70543, 70543,
   70582, 70582, 70584, 70584, 70587, 70601, 70603, 70603, 70606, 70608, 70610, 70610, 70614, 70614, 70617, 70655, 70712, 70719, 70722, 70724,
   70726, 70726, 70748, 70748, 70750, 70750, 70754, 70783, 70832, 70832, 70835, 70840, 70842, 70842, 70845, 70845, 70847, 70848, 70850, 70851,
   70856, 70863, 70874, 71039, 71087, 71087, 71090, 71095, 71100, 71101, 71103, 71104, 71132, 71167, 71219, 71226, 71229, 71229, 71231, 71232,
   71237, 71247, 71258, 71263, 71277, 71295, 71339, 71339, 71341, 71341, 71344, 71351, 71354, 71359, 71370, 71375, 71396, 71423, 71451, 71453,
   71455, 71455, 71458, 71461, 71463, 71471, 71495, 71679, 71727, 71735, 71737, 71738, 71740, 71839, 71923, 71934, 71943, 71944, 71946, 71947,
   71956, 71956, 71959, 71959, 71984, 71984, 71990, 71990, 71993, 71998, 72003, 72003, 72007, 72015, 72026, 72095, 72104, 72105, 72148, 72155,
   72160, 72160, 72165, 72191, 72193, 72202, 72243, 72248, 72251, 72254, 72263, 72271, 72273, 72278, 72281, 72283, 72330, 72342, 72344, 72345,
   72355, 72367, 72441, 72447, 72458, 72544, 72546, 72548, 72550, 72550, 72552, 72639, 72674, 72687, 72698, 72703, 72713, 72713, 72752, 72765,
   72767, 72767, 72774, 72783, 72813, 72815, 72848, 72872, 72874, 72880, 72882, 72883, 72885, 72959, 72967, 72967, 72970, 72970, 73009, 73029,
   73031, 73039, 73050, 73055, 73062, 73062, 73065, 73065, 73103, 73106, 73109, 73109, 73111, 73111, 73113, 73119, 73130, 73135, 73180, 73183,
   73194, 73439, 73459, 73460, 73465, 73473, 73489, 73489, 73526, 73533, 73536, 73538, 73562, 73647, 73649, 73663, 73714, 73726, 74650, 74751,
   74863, 74863, 74869, 74879, 75076, 77711, 77811, 77823, 78896, 78912, 78919, 78943, 82939, 82943, 83527, 90367, 90398, 90409, 90413, 90415,
   90426, 92159, 92729, 92735, 92767, 92767, 92778, 92781, 92863, 92863, 92874, 92879, 92910, 92916, 92918, 92927, 92976, 92982, 92998, 93007,
   93018, 93018, 93026, 93026, 93048, 93052, 93072, 93503, 93562, 93759, 93851, 93855, 93881, 93882, 93908, 93951, 94027, 94031, 94088, 94098,
   94112, 94175, 94180, 94193, 94199, 94207, 101590, 101630, 101663, 101759, 101875, 110575, 110580, 110580, 110588, 110588, 110591, 110591, 110883, 110897,
   110899, 110927, 110931, 110932, 110934, 110947, 110952, 110959, 111356, 113663, 113771, 113775, 113789, 113791, 113801, 113807, 113818, 113819, 113821, 113822,
   113824, 117759, 118013, 118015, 118452, 118457, 118481, 118495, 118513, 118607, 118724, 118783, 119030, 119039, 119079, 119080, 119141, 119145, 119149, 119170,
   119173, 119179, 119210, 119213, 119275, 119295, 119362, 119364, 119366, 119487, 119508, 119519, 119540, 119551, 119639, 119647, 119673, 119807, 119893, 119893,
   119965, 119965, 119968, 119969, 119971, 119972, 119975, 119976, 119981, 119981, 119994, 119994, 119996, 119996, 120004, 120004, 120070, 120070, 120075, 120076,
   120085, 120085, 120093, 120093, 120122, 120122, 120127, 120127, 120133, 120133, 120135, 120137, 120145, 120145, 120486, 120487, 120780, 120781, 121344, 121398,
   121403, 121452, 121461, 121461, 121476, 121476, 121484, 122623, 122655, 122660, 122667, 122927, 122990, 123135, 123181, 123190, 123198, 123199, 123210, 123213,
   123216, 123535, 123566, 123583, 123628, 123631, 123642, 123646, 123648, 124111, 124140, 124143, 124154, 124367, 124398, 124399, 124411, 124414, 124416, 124607,
   124639, 124639, 124643, 124643, 124646, 124646, 124654, 124655, 124661, 124669, 124672, 124895, 124903, 124903, 124908, 124908, 124911, 124911, 124927, 124927,
   125125, 125126, 125136, 125183, 125252, 125258, 125260, 125263, 125274, 125277, 125280, 126064, 126133, 126208, 126270, 126463, 126468, 126468, 126496, 126496,
   126499, 126499, 126501, 126502, 126504, 126504, 126515, 126515, 126520, 126520, 126522, 126522, 126524, 126529, 126531, 126534, 126536, 126536, 126538, 126538,
   126540, 126540, 126544, 126544, 126547, 126547, 126549, 126550, 126552, 126552, 126554, 126554, 126556, 126556, 126558, 126558, 126560, 126560, 126563, 126563,
   126565, 126566, 126571, 126571, 126579, 126579, 126584, 126584, 126589, 126589, 126591, 126591, 126602, 126602, 126620, 126624, 126628, 126628, 126634, 126634,
   126652, 126703, 126706, 126975, 127020, 127023, 127124, 127135, 127151, 127152, 127168, 127168, 127184, 127184, 127222, 127231, 127406, 127461, 127491, 127503,
   127548, 127551, 127561, 127567, 127570, 127583, 127590, 127743, 128729, 128731, 128749, 128751, 128765, 128767, 128986, 128991, 129004, 129007, 129009, 129023,
   129036, 129039, 129096, 129103, 129114, 129119, 129160, 129167, 129198, 129199, 129212, 129215, 129218, 129231, 129241, 129279, 129624, 129631, 129646, 129647,
   129661, 129663, 129675, 129677, 129735, 129735, 129737, 129740, 129757, 129758, 129771, 129774, 129785, 129791, 129939, 129939, 130043, 131071, 173792, 173823,
   178206, 178207, 183982, 183983, 191457, 191471, 192094, 194559, 195102, 196607, 201547, 201551, 210042, 1114111]

# S4.350 S2.58 (spec twin) is c inside one of the ranges `lo, hi, …`: a tail walk over the whole table
def in_ranges(xs: List<&2, U32>, +c: U32, found: Bool) -> Bool:
  match xs:
    case Con{+lo, Con{+hi, rest}}:
      in_ranges(rest, c, (found || ((c >= lo : U32) && (c <= hi : U32))))
    case other:
      found

# S4.350 S2.58 (spec twin) a code point `escape_debug` writes as `\u{…}` (after the named escapes): below U+0020 or
# DEL within ASCII, the measured table outside it (only non-ASCII text walks the table)
def dbg_hidden(ascii: Bool, +c: U32) -> Bool:
  match ascii:
    case True{}:
      ((c < 32 : U32) || U32.is_eq(c, 127))
    case False{}:
      in_ranges(hidden_table(), c, False{})

# S4.350 S2.58 (spec twin) the letter of a named escape: `\0` `\t` `\n` `\r` `\"` `\\`, or 1 when the code point has
# no name
def dbg_named(+c: U32) -> U32:
  Bool.pick(U32, U32.is_eq(c, 0), 48, Bool.pick(U32, U32.is_eq(c, 9), 116, Bool.pick(U32, U32.is_eq(c, 10), 110, Bool.pick(U32, U32.is_eq(c, 13), 114, Bool.pick(U32, U32.is_eq(c, 34), 34, Bool.pick(U32, U32.is_eq(c, 92), 92, 1))))))

# S4.350 S2.58 (spec twin) the number of lower-case hex digits of a code point, without leading zeros
def hex_width(+c: U32) -> Nat:
  Bool.pick(Nat, (c < 16 : U32), 1n, Bool.pick(Nat, (c < 256 : U32), 2n, Bool.pick(Nat, (c < 4096 : U32), 3n, Bool.pick(Nat, (c < 65536 : U32), 4n, Bool.pick(Nat, (c < 1048576 : U32), 5n, 6n)))))

# S4.350 S2.58 (spec twin) the n lowest hex digits of c in order, put in front of `fwd` (the least significant is
# taken first, so each more significant one lands in front of it)
def hex_fwd(n: Nat, +c: U32, fwd: List<&2, U32>) -> List<&2, U32>:
  match n:
    case 0n:
      fwd
    case 1n+m:
      hex_fwd(m, (c >> 4n : U32), hex_digit((c .&. 15 : U32), ((c .&. 15 : U32) < 10 : U32)) <> fwd)

# S4.350 S2.58 (spec twin) code points in order pushed onto a REVERSED accumulator
def push_all(fwd: List<&2, U32>, acc: List<&2, U32>) -> List<&2, U32>:
  match fwd:
    case Nil{}:
      acc
    case Con{d, rest}:
      push_all(rest, d <> acc)

# S4.350 S2.58 (spec twin) the hex digits of c, most significant first, pushed onto a REVERSED accumulator
def hex_digits(+c: U32, n: Nat, acc: List<&2, U32>) -> List<&2, U32>:
  push_all(hex_fwd(n, c, Nil{}), acc)

# S4.350 S2.58 (spec twin) one code point pushed, Debug-escaped, onto a REVERSED accumulator
def dbg_step(plain: Bool, hidden: Bool, +c: U32, +named: U32, acc: List<&2, U32>) -> List<&2, U32>:
  match plain hidden:
    case False{} _:
      named <> (92 <> acc)
    case True{} True{}:
      125 <> hex_digits(c, hex_width(c), 123 <> (117 <> (92 <> acc)))
    case True{} False{}:
      c <> acc

# S4.350 S2.58 (spec twin) the loop: the string is the measure, acc is reversed
def dbg_go(s: String, acc: List<&2, U32>) -> List<&2, U32>:
  match s:
    case SNil{}:
      acc
    case SCon{Chr{+c}, rest}:
      dbg_go(rest, dbg_step(U32.is_eq(dbg_named(c), 1), dbg_hidden((c < 128 : U32), c), c, dbg_named(c), acc))

# S4.350 S2.58 (spec twin) a text as Rust's `{:?}` writes it, quotes included: `\0` `\t` `\n` `\r` `\"` `\\` by name,
# a hidden code point as `\u{hex}` (lower case, no leading zeros), everything else raw (`"x\ty\\z\u{7f}\u{a0}"`)
def debug_quoted(s: String) -> String:
  "\"" ++ unreverse(dbg_go(s, Nil{}), "\"")

# S4.350 S2.58 (spec twin) the tail of a refused `metadata`: the text as Rust's `{:?}` writes it, serde_json's
# message, and its `line L column C` (`found "{\"a\":": EOF while parsing a value at line 1 column 5`)
def meta_found(+raw: String, msg: String, place: String) -> String:
  "found " ++ debug_quoted(raw) ++ ": " ++ msg ++ " at " ++ place

# S9.1 (spec twin) the items of a context list, one per line at eight spaces, comma separated
def list_lines(items: List<&2, String>) -> String:
  match items:
    case Nil{}:
      ""
    case Con{item, Nil{}}:
      "        " ++ quoted(item) ++ "\n"
    case Con{item, rest}:
      "        " ++ quoted(item) ++ ",\n" ++ list_lines(rest)

# S9.1 (spec twin) a context value; a list opens on the key's line and closes at six spaces
def ctx_value(v: CtxVal) -> String:
  match v:
    case CStr{text}:
      quoted(text)
    case CBare{text}:
      text
    case CList{Nil{}}:
      "[]"
    case CList{items}:
      "[\n" ++ list_lines(items) ++ "      ]"

# S9.1 (spec twin) the context members, one per line at six spaces, comma separated
def ctx_lines(members: List<&2, CtxMember>) -> String:
  match members:
    case Nil{}:
      ""
    case Con{CtxMember{key, value}, Nil{}}:
      "      " ++ quoted(key) ++ ": " ++ ctx_value(value) ++ "\n"
    case Con{CtxMember{key, value}, rest}:
      "      " ++ quoted(key) ++ ": " ++ ctx_value(value) ++ ",\n" ++ ctx_lines(rest)

# S9.1 (spec twin) `null` for no context, else a pretty object closing at four spaces
def ctx_text(members: List<&2, CtxMember>) -> String:
  match members:
    case Nil{}:
      "null"
    case Con{first, rest}:
      "{\n" ++ ctx_lines(first <> rest) ++ "    }"

# S9.1 (spec twin) `null` for no hint, else the string
def hint_json(hint: Maybe<&2, String>) -> String:
  match hint:
    case None{}:
      "null"
    case Some{text}:
      quoted(text)

# S9.1 (spec twin) `true` / `false`
def bool_text(b: Bool) -> String:
  match b:
    case True{}:
      "true"
    case False{}:
      "false"

# S9.1 (spec twin) the JSON-mode rendering, written to STDOUT
def json_text(f: Failure) -> String:
  match f:
    case Failure{code, message, hint, retryable, context, _}:
      "{\n  \"error\": {\n    \"code\": " ++ quoted(code) ++ ",\n    \"message\": " ++ quoted(message) ++ ",\n    \"hint\": " ++ hint_json(hint) ++ ",\n    \"retryable\": " ++ bool_text(retryable) ++ ",\n    \"context\": " ++ ctx_text(context) ++ "\n  }\n}\n"

# S9.2 (spec twin) the `Hint:` line, when there is a hint
def hint_plain(hint: Maybe<&2, String>) -> String:
  match hint:
    case None{}:
      ""
    case Some{text}:
      "Hint: " ++ text ++ "\n"

# S9.2 (spec twin) the plain-mode rendering, written to STDERR
def plain_text(f: Failure) -> String:
  match f:
    case Failure{_, message, hint, _, _, _}:
      "Error: " ++ message ++ "\n" ++ hint_plain(hint)

# S9.6 (spec twin) the process exit code of a failure
def exit_of(f: Failure) -> U32:
  match f:
    case Failure{_, _, _, _, _, exit}:
      exit

# S9.8 (spec twin) no `.beads` workspace was found: NOT_INITIALIZED, exit 2
def not_initialized() -> Failure:
  Failure{"NOT_INITIALIZED", "Beads not initialized: run 'br init' first", Some{"Run: br init"}, False{}, Nil{}, 2}

# S9.6 (spec twin) a surface of the contract the port does not implement yet. Exit 1 is the
# contract's internal-error code; the message is the port's own, so every such case FAILS
# its golden, which is the truthful state of an unported command.
def unported() -> Failure:
  Failure{"INTERNAL_ERROR", "beads_bend: this command is not ported yet", None{}, False{}, Nil{}, 1}
