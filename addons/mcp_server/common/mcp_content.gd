## MCPContent - Content Block
## Represents a content block in a tool result (text or image).
class_name MCPContent
extends RefCounted

var type: String  # "text" or "image"
var text: String  # For type="text"
var data: String  # Base64 for type="image"
var mime_type: String  # For type="image"


func _init(content_type: String = "text") -> void:
	type = content_type
	mime_type = "image/png"


## Creates a text content block
static func text_content(content_text: String) -> MCPContent:
	var content := MCPContent.new("text")
	content.text = content_text
	return content


## Creates an image content block from base64 data
static func image_content(base64_data: String, image_mime_type: String = "image/png") -> MCPContent:
	var content := MCPContent.new("image")
	content.data = base64_data
	content.mime_type = image_mime_type
	return content


## Converts to dictionary for JSON serialization
func to_dict() -> Dictionary:
	var result: Dictionary = {"type": type}
	match type:
		"text":
			result["text"] = text
		"image":
			result["data"] = data
			result["mimeType"] = mime_type
	return result
