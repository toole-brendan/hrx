package email

import (
	"bytes"
	"encoding/base64"
	"fmt"
)

type DA2062EmailService struct {
	emailService EmailService // Assuming there's an existing email service
}

func NewDA2062EmailService(emailService EmailService) *DA2062EmailService {
	return &DA2062EmailService{
		emailService: emailService,
	}
}

func (s *DA2062EmailService) SendDA2062Email(
	recipients []string,
	pdfBuffer *bytes.Buffer,
	formNumber string,
	senderInfo UserInfo,
) error {
	subject := fmt.Sprintf("DA Form 2062 - Hand Receipt #%s", formNumber)

	// Create email body
	body := s.generateEmailBody(formNumber, senderInfo)

	// Create attachment
	attachment := EmailAttachment{
		Filename:    fmt.Sprintf("DA2062_%s.pdf", formNumber),
		Content:     base64.StdEncoding.EncodeToString(pdfBuffer.Bytes()),
		ContentType: "application/pdf",
	}

	// Send email with attachment
	emailRequest := EmailRequest{
		To:          recipients,
		Subject:     subject,
		Body:        body,
		Attachments: []EmailAttachment{attachment},
		IsHTML:      true,
	}

	return s.emailService.SendEmail(emailRequest)
}

func (s *DA2062EmailService) generateEmailBody(formNumber string, senderInfo UserInfo) string {
	return fmt.Sprintf(`
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>DA Form 2062 - Hand Receipt</title>
</head>
<body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
    <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
        <h2 style="color: #2c3e50; border-bottom: 2px solid #3498db; padding-bottom: 10px;">
            DA Form 2062 - Hand Receipt
        </h2>
        
        <p>You have received a DA Form 2062 (Hand Receipt) document.</p>
        
        <div style="background-color: #f8f9fa; padding: 15px; border-radius: 5px; margin: 15px 0;">
            <h3 style="margin-top: 0; color: #495057;">Document Details:</h3>
            <ul style="list-style-type: none; padding-left: 0;">
                <li><strong>Form Number:</strong> %s</li>
                <li><strong>Generated Date:</strong> %s</li>
                <li><strong>From:</strong> %s %s</li>
                <li><strong>Title:</strong> %s</li>
            </ul>
        </div>
        
        <p>Please find the attached PDF document for your records. This document contains official property accountability information.</p>
        
        <div style="background-color: #fff3cd; border: 1px solid #ffeaa7; padding: 10px; border-radius: 5px; margin: 15px 0;">
            <p style="margin: 0;"><strong>Note:</strong> This is an official military document. Please retain for your records and ensure proper handling according to applicable regulations.</p>
        </div>
        
        <hr style="border: none; border-top: 1px solid #dee2e6; margin: 20px 0;">
        
        <p style="font-size: 0.9em; color: #6c757d;">
            This message was automatically generated by the HandReceipt system.<br>
            For questions regarding this document, please contact the sender directly.
        </p>
    </div>
</body>
</html>`,
		formNumber,
		getCurrentDate(),
		senderInfo.Rank,
		senderInfo.Name,
		senderInfo.Title,
	)
}

func getCurrentDate() string {
	// This would use proper time formatting
	return "Current Date" // Placeholder
}

// These structs should match your existing email service interfaces
type UserInfo struct {
	Name  string
	Rank  string
	Title string
	Phone string
}

type EmailAttachment struct {
	Filename    string
	Content     string
	ContentType string
}

type EmailRequest struct {
	To          []string
	Subject     string
	Body        string
	Attachments []EmailAttachment
	IsHTML      bool
}

// EmailService interface - this should match your existing email service
type EmailService interface {
	SendEmail(request EmailRequest) error
}
