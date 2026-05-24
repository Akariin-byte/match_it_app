package handler

import (
	"github.com/gin-gonic/gin"
)

// JSONOK 统一成功响应
func JSONOK(c *gin.Context, data any) {
	c.JSON(200, data)
}

// JSONError 统一错误响应
func JSONError(c *gin.Context, status int, message string) {
	c.JSON(status, gin.H{"error": message})
}
