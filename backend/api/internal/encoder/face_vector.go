package encoder

import (
	"math"

	pgvector "github.com/pgvector/pgvector-go"
)

// 与 Flutter FaceVectorEncoder.defaultVocabulary 保持一致
var vocabulary = []string{
	"策略思维", "桌游爱好者", "逻辑型",
	"美食探索", "社交型", "慢节奏",
	"运动达人", "活力型", "竞争意识",
	"开放", "随和",
	"休闲派", "平衡型", "认真派", "硬核派",
	"团队配合", "拍照打卡", "早起党",
}

var tagIndex map[string]int

func init() {
	tagIndex = make(map[string]int, len(vocabulary))
	for i, tag := range vocabulary {
		tagIndex[tag] = i
	}
}

// EncodeTraits multi-hot + L2 归一化 → pgvector.Vector(18)
func EncodeTraits(traits []string) pgvector.Vector {
	vec := make([]float32, len(vocabulary))
	hit := 0
	for _, tag := range traits {
		if idx, ok := tagIndex[tag]; ok {
			vec[idx] = 1
			hit++
		}
	}
	if hit == 0 {
		return pgvector.NewVector(vec)
	}
	var sum float64
	for _, v := range vec {
		sum += float64(v * v)
	}
	norm := math.Sqrt(sum)
	if norm == 0 {
		return pgvector.NewVector(vec)
	}
	for i := range vec {
		vec[i] = float32(float64(vec[i]) / norm)
	}
	return pgvector.NewVector(vec)
}
