package handlers

/* ------------------------------------------------------------------
   ⚠️ Entire file deprecated – old "AI handler" was a thin wrapper
      around Azure OpenAI. All calls now go through ImportDA2062 in
      da2062_handler.go which uses the new Claude AI service in
      internal/services/ai/claude_da2062_service.go.
------------------------------------------------------------------ */

/*
import (
	"context"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/toole-brendan/handreceipt-go/internal/domain"
	"github.com/toole-brendan/handreceipt-go/internal/ledger"
	"github.com/toole-brendan/handreceipt-go/internal/repository"
	"github.com/toole-brendan/handreceipt-go/internal/services/ai"
	"github.com/toole-brendan/handreceipt-go/internal/services/nsn"
	"github.com/toole-brendan/handreceipt-go/internal/services/ocr"
)

// [Original file content preserved but commented out]
// ... rest of file content ...
*/