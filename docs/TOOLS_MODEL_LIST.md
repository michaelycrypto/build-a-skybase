# Complete List of 3D Models Required in ReplicatedStorage.Assets.Tools

This document lists ALL items that need 3D models in `game.ReplicatedStorage.Assets.Tools` for wielding in hand and rendering dropped items.

## Model Naming Convention

Models should be named using the **item name** (e.g., "Apple", "Stick") or **item ID** (e.g., "37" for Apple). The system will look for models in this order:
1. `ReplicatedStorage.Assets.Tools[modelName]` (primary)
2. `ReplicatedStorage.Tools[modelName]` (legacy fallback)

Each model should be:
- A `MeshPart` directly, OR
- A `Model`/`Folder` containing a `MeshPart` (system finds it recursively)

---

## Tools (Required - Already Referenced by Name)

1. **Sword** - For sword tools
2. **Axe** - For axe tools
3. **Shovel** - For shovel tools
4. **Pickaxe** - For pickaxe tools
5. **Bow** - For bow tools (with variants: `Bow`, `Bow_Charging`, `Bow_Charged`)

---

## Crafting Materials & Items

6. **Stick** (ID: 28)
7. **Coal** (ID: 32)
8. **Iron Ingot** (ID: 33)
9. **Diamond** (ID: 34)
10. **Copper Ingot** (ID: 105)
11. **Steel Ingot** (ID: 108)
12. **Bluesteel Ingot** (ID: 109)
13. **Tungsten Ingot** (ID: 110)
14. **Titanium Ingot** (ID: 111)
15. **Bluesteel Dust** (ID: 115)

---

## Food Items

16. **Apple** (ID: 37)
17. **Wheat** (ID: 71)
18. **Potato** (ID: 72)
19. **Carrot** (ID: 73)
20. **Beetroot** (ID: 75)

---

## Seeds & Farming Items

21. **Wheat Seeds** (ID: 70)
22. **Beetroot Seeds** (ID: 74)
23. **Compost** (ID: 96)

---

## Ores (as items when mined)

24. **Coal Ore** (ID: 29) - Drops as Coal item
25. **Iron Ore** (ID: 30) - Drops as Iron Ore item
26. **Diamond Ore** (ID: 31) - Drops as Diamond item
27. **Copper Ore** (ID: 98) - Drops as Copper Ore item
28. **Bluesteel Ore** (ID: 101) - Drops as Bluesteel Dust item
29. **Tungsten Ore** (ID: 102) - Drops as Tungsten Ore item
30. **Titanium Ore** (ID: 103) - Drops as Titanium Ore item

---

## Saplings (Cross-shaped items)

31. **Oak Sapling** (ID: 16)
32. **Spruce Sapling** (ID: 40)
33. **Jungle Sapling** (ID: 45)
34. **Dark Oak Sapling** (ID: 50)
35. **Birch Sapling** (ID: 55)
36. **Acacia Sapling** (ID: 60)

---

## Decorative/Non-Solid Blocks (Cross-shaped)

37. **Tall Grass** (ID: 7)
38. **Flower** (ID: 8)

---

## Full Blocks (Can be held in hand)

These are solid blocks that can be placed, but players can also hold them in inventory and they render as 3D cubes when dropped:

### Basic Blocks
39. **Grass Block** (ID: 1)
40. **Dirt** (ID: 2)
41. **Stone** (ID: 3)
42. **Bedrock** (ID: 4)
43. **Oak Log** (ID: 5)
44. **Oak Leaves** (ID: 6)
45. **Chest** (ID: 9)
46. **Sand** (ID: 10)
47. **Stone Bricks** (ID: 11)
48. **Oak Planks** (ID: 12)
49. **Crafting Table** (ID: 13)
50. **Cobblestone** (ID: 14)
51. **Bricks** (ID: 15)
52. **Oak Fence** (ID: 27)
53. **Furnace** (ID: 35)
54. **Glass** (ID: 36)

### Wood Variants
55. **Spruce Log** (ID: 38)
56. **Spruce Planks** (ID: 39)
57. **Spruce Leaves** (ID: 64)
58. **Jungle Log** (ID: 43)
59. **Jungle Planks** (ID: 44)
60. **Jungle Leaves** (ID: 65)
61. **Dark Oak Log** (ID: 48)
62. **Dark Oak Planks** (ID: 49)
63. **Dark Oak Leaves** (ID: 66)
64. **Birch Log** (ID: 53)
65. **Birch Planks** (ID: 54)
66. **Birch Leaves** (ID: 67)
67. **Acacia Log** (ID: 58)
68. **Acacia Planks** (ID: 59)
69. **Acacia Leaves** (ID: 68)

### Stairs
70. **Oak Stairs** (ID: 17)
71. **Stone Stairs** (ID: 18)
72. **Cobblestone Stairs** (ID: 19)
73. **Stone Brick Stairs** (ID: 20)
74. **Brick Stairs** (ID: 21)
75. **Spruce Stairs** (ID: 41)
76. **Jungle Stairs** (ID: 46)
77. **Dark Oak Stairs** (ID: 51)
78. **Birch Stairs** (ID: 56)
79. **Acacia Stairs** (ID: 61)
80. **Andesite Stairs** (ID: 212)
81. **Diorite Stairs** (ID: 213)
82. **Sandstone Stairs** (ID: 214)
83. **Nether Brick Stairs** (ID: 215)
84. **Quartz Stairs** (ID: 219)
85. **Granite Stairs** (ID: 224)

### Slabs
86. **Oak Slab** (ID: 22)
87. **Stone Slab** (ID: 23)
88. **Cobblestone Slab** (ID: 24)
89. **Stone Brick Slab** (ID: 25)
90. **Brick Slab** (ID: 26)
91. **Spruce Slab** (ID: 42)
92. **Jungle Slab** (ID: 47)
93. **Dark Oak Slab** (ID: 52)
94. **Birch Slab** (ID: 57)
95. **Acacia Slab** (ID: 62)
96. **Granite Slab** (ID: 225)
97. **Blackstone Slab** (ID: 226)
98. **Smooth Quartz Slab** (ID: 227)

### Ores (as blocks)
99. **Coal Ore** (ID: 29)
100. **Iron Ore** (ID: 30)
101. **Diamond Ore** (ID: 31)
102. **Copper Ore** (ID: 98)
103. **Bluesteel Ore** (ID: 101)
104. **Tungsten Ore** (ID: 102)
105. **Titanium Ore** (ID: 103)

### Ingot Blocks (9x ingots)
106. **Copper Block** (ID: 116)
107. **Coal Block** (ID: 117)
108. **Iron Block** (ID: 118)
109. **Steel Block** (ID: 119)
110. **Bluesteel Block** (ID: 120)
111. **Tungsten Block** (ID: 121)
112. **Titanium Block** (ID: 122)

### Stained Glass (16 colors)
113. **White Stained Glass** (ID: 123)
114. **Orange Stained Glass** (ID: 124)
115. **Magenta Stained Glass** (ID: 125)
116. **Light Blue Stained Glass** (ID: 126)
117. **Yellow Stained Glass** (ID: 127)
118. **Lime Stained Glass** (ID: 128)
119. **Pink Stained Glass** (ID: 129)
120. **Gray Stained Glass** (ID: 130)
121. **Light Gray Stained Glass** (ID: 131)
122. **Cyan Stained Glass** (ID: 132)
123. **Purple Stained Glass** (ID: 133)
124. **Blue Stained Glass** (ID: 134)
125. **Brown Stained Glass** (ID: 135)
126. **Green Stained Glass** (ID: 136)
127. **Red Stained Glass** (ID: 137)
128. **Black Stained Glass** (ID: 138)

### Terracotta (17 colors)
129. **Terracotta** (ID: 139)
130. **White Terracotta** (ID: 140)
131. **Orange Terracotta** (ID: 141)
132. **Magenta Terracotta** (ID: 142)
133. **Light Blue Terracotta** (ID: 143)
134. **Yellow Terracotta** (ID: 144)
135. **Lime Terracotta** (ID: 145)
136. **Pink Terracotta** (ID: 146)
137. **Gray Terracotta** (ID: 147)
138. **Light Gray Terracotta** (ID: 148)
139. **Cyan Terracotta** (ID: 149)
140. **Purple Terracotta** (ID: 150)
141. **Blue Terracotta** (ID: 151)
142. **Brown Terracotta** (ID: 152)
143. **Green Terracotta** (ID: 153)
144. **Red Terracotta** (ID: 154)
145. **Black Terracotta** (ID: 155)

### Wool (16 colors)
146. **White Wool** (ID: 156)
147. **Orange Wool** (ID: 157)
148. **Magenta Wool** (ID: 158)
149. **Light Blue Wool** (ID: 159)
150. **Yellow Wool** (ID: 160)
151. **Lime Wool** (ID: 161)
152. **Pink Wool** (ID: 162)
153. **Gray Wool** (ID: 163)
154. **Light Gray Wool** (ID: 164)
155. **Cyan Wool** (ID: 165)
156. **Purple Wool** (ID: 166)
157. **Blue Wool** (ID: 167)
158. **Brown Wool** (ID: 168)
159. **Green Wool** (ID: 169)
160. **Red Wool** (ID: 170)
161. **Black Wool** (ID: 171)

### Additional Blocks
162. **Nether Bricks** (ID: 172)
163. **Gravel** (ID: 173)
164. **Coarse Dirt** (ID: 174)
165. **Sandstone** (ID: 175)
166. **Diorite** (ID: 176)
167. **Polished Diorite** (ID: 177)
168. **Andesite** (ID: 178)
169. **Polished Andesite** (ID: 179)

### Concrete (16 colors)
170. **White Concrete** (ID: 180)
171. **Orange Concrete** (ID: 181)
172. **Magenta Concrete** (ID: 182)
173. **Light Blue Concrete** (ID: 183)
174. **Yellow Concrete** (ID: 184)
175. **Lime Concrete** (ID: 185)
176. **Pink Concrete** (ID: 186)
177. **Gray Concrete** (ID: 187)
178. **Light Gray Concrete** (ID: 188)
179. **Cyan Concrete** (ID: 189)
180. **Purple Concrete** (ID: 190)
181. **Blue Concrete** (ID: 191)
182. **Brown Concrete** (ID: 192)
183. **Green Concrete** (ID: 193)
184. **Red Concrete** (ID: 194)
185. **Black Concrete** (ID: 195)

### Concrete Powder (16 colors)
186. **White Concrete Powder** (ID: 196)
187. **Orange Concrete Powder** (ID: 197)
188. **Magenta Concrete Powder** (ID: 198)
189. **Light Blue Concrete Powder** (ID: 199)
190. **Yellow Concrete Powder** (ID: 200)
191. **Lime Concrete Powder** (ID: 201)
192. **Pink Concrete Powder** (ID: 202)
193. **Gray Concrete Powder** (ID: 203)
194. **Light Gray Concrete Powder** (ID: 204)
195. **Cyan Concrete Powder** (ID: 205)
196. **Purple Concrete Powder** (ID: 206)
197. **Blue Concrete Powder** (ID: 207)
198. **Brown Concrete Powder** (ID: 208)
199. **Green Concrete Powder** (ID: 209)
200. **Red Concrete Powder** (ID: 210)
201. **Black Concrete Powder** (ID: 211)

### Quartz Blocks
202. **Quartz Block** (ID: 216)
203. **Quartz Pillar** (ID: 217)
204. **Chiseled Quartz Block** (ID: 218)

### Stone Variants
205. **Blackstone** (ID: 220)
206. **Granite** (ID: 221)
207. **Polished Granite** (ID: 222)
208. **Podzol** (ID: 223)

### Farming Blocks
209. **Farmland** (ID: 69)

### Special Blocks
210. **Cobblestone Minion** (ID: 97)
211. **Coal Minion** (ID: 123)

---

## Crop Stages (Cross-shaped, typically not held but can be)

These are typically placed blocks, but can theoretically be items:
- **Wheat Crop Stages** (IDs: 76-83)
- **Potato Crop Stages** (IDs: 84-87)
- **Carrot Crop Stages** (IDs: 88-91)
- **Beetroot Crop Stages** (IDs: 92-95)

*Note: Crop stages are usually placed blocks, but if they can be items, they would need models too.*

---

## Summary

**Total Items Requiring Models: ~211+ items**

### Breakdown:
- **Tools**: 5 items (Sword, Axe, Shovel, Pickaxe, Bow)
- **Crafting Materials**: 10 items
- **Food Items**: 5 items
- **Seeds & Farming**: 3 items
- **Ores (as items)**: 7 items
- **Saplings**: 6 items
- **Decorative**: 2 items
- **Full Blocks**: ~173 items (all placeable blocks)

### Priority Order:
1. **High Priority**: Tools (5), Food Items (5), Crafting Materials (10), Seeds (3)
2. **Medium Priority**: Ores (7), Saplings (6), Ingot Blocks (7)
3. **Low Priority**: All full blocks (can use procedural cube rendering as fallback)

---

## Notes

- Models can be named by **item name** (e.g., "Apple") or **item ID** (e.g., "37")
- The system will fall back to procedural rendering (cube for blocks, cross-shape for items) if a model is not found
- For tools, models are **required** (no fallback)
- For blocks, 3D models are **optional** but recommended for better visuals when held/dropped

---

*Last Updated: January 2026*
*Related: [PRD_FOOD_CONSUMABLES.md](./PRDs/PRD_FOOD_CONSUMABLES.md), [IMPLEMENTATION_PLAN_FOOD_CONSUMABLES.md](./IMPLEMENTATION_PLAN_FOOD_CONSUMABLES.md)*
