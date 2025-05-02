public with sharing class ExpenseExtractorController {
    @AuraEnabled
    public static Map<String, Object> extractExpenseDetails(String contentVersionId, String expenseReportId) {
        try {
            System.debug('extractExpenseDetails received contentVersionId: ' + contentVersionId);
            System.debug('extractExpenseDetails received expenseReportId: ' + expenseReportId);
            
            if (contentVersionId == null) {
                System.debug('ContentVersionId is null');
                throw new AuraHandledException('Content Version ID is required');
            }
            
            // Get the content version
            System.debug('Querying ContentVersion with ID: ' + contentVersionId);
            ContentVersion cv = [SELECT Id, VersionData, Title, FileExtension 
                               FROM ContentVersion 
                               WHERE Id = :contentVersionId 
                               WITH SECURITY_ENFORCED];
            System.debug('Found ContentVersion: ' + JSON.serialize(cv));
            
            // Convert the file to base64
            String base64Data = EncodingUtil.base64Encode(cv.VersionData);
            System.debug('Base64 data length: ' + base64Data.length());
            
            // Call Gemini API to extract details
            System.debug('Calling Gemini API');
            Map<String, Object> extractedData = callGeminiAPI(base64Data, cv.FileExtension);
            System.debug('Extracted data: ' + JSON.serialize(extractedData));
            
            return extractedData;
        } catch (Exception e) {
            System.debug('Error in extractExpenseDetails: ' + e.getMessage() + '\n' + e.getStackTraceString());
            throw new AuraHandledException('Error extracting expense details: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static Map<String, Object> createExpenseLineItems(Map<String, Object> params) {
        try {
            System.debug('=== Start createExpenseLineItems ===');
            System.debug('Raw params: ' + params);
            System.debug('Serialized params: ' + JSON.serialize(params));
            
            // Validate parameters
            if (params == null) {
                String errorMsg = 'Parameters object is null';
                System.debug('Error: ' + errorMsg);
                return new Map<String, Object>{
                    'isSuccess' => false,
                    'errorMessage' => errorMsg
                };
            }
            
            // Log all keys in params
            System.debug('Available keys in params: ' + params.keySet());
            
            String expenseReportId = (String)params.get('expenseReportId');
            System.debug('expenseReportId: ' + expenseReportId);
            
            Object extractedDataObj = params.get('extractedData');
            System.debug('extractedDataObj: ' + (extractedDataObj != null ? String.valueOf(extractedDataObj) : 'null'));
            
            if (String.isBlank(expenseReportId)) {
                String errorMsg = 'Expense Report ID is required';
                System.debug('Error: ' + errorMsg);
                return new Map<String, Object>{
                    'isSuccess' => false,
                    'errorMessage' => errorMsg
                };
            }
            
            if (extractedDataObj == null) {
                String errorMsg = 'Extracted data is required';
                System.debug('Error: ' + errorMsg);
                return new Map<String, Object>{
                    'isSuccess' => false,
                    'errorMessage' => errorMsg
                };
            }
            
            // Convert extracted data to proper format
            Map<String, Object> extractedData;
            try {
                if (extractedDataObj instanceof Map<String, Object>) {
                    System.debug('extractedDataObj is already a Map');
                    extractedData = (Map<String, Object>)extractedDataObj;
                } else if (extractedDataObj instanceof String) {
                    System.debug('extractedDataObj is a String, attempting to parse');
                    extractedData = (Map<String, Object>)JSON.deserializeUntyped((String)extractedDataObj);
                } else {
                    System.debug('extractedDataObj is of unexpected type, attempting to serialize and parse');
                    String serialized = JSON.serialize(extractedDataObj);
                    System.debug('Attempting to parse serialized data: ' + serialized);
                    extractedData = (Map<String, Object>)JSON.deserializeUntyped(serialized);
                }
            } catch (Exception e) {
                String errorMsg = 'Failed to process extracted data: ' + e.getMessage();
                System.debug('Error: ' + errorMsg);
                System.debug('Exception stack trace: ' + e.getStackTraceString());
                return new Map<String, Object>{
                    'isSuccess' => false,
                    'errorMessage' => errorMsg
                };
            }
            
            System.debug('Final extractedData: ' + JSON.serialize(extractedData));
            
            // Create the expense line item
            try {
                createExpenseLineItem(extractedData, expenseReportId);
                System.debug('Successfully created expense line item');
                return new Map<String, Object>{
                    'isSuccess' => true,
                    'message' => 'Expense line item created successfully'
                };
            } catch (Exception e) {
                String errorMsg = 'Error creating expense line item: ' + e.getMessage();
                System.debug('Error: ' + errorMsg);
                System.debug('Exception stack trace: ' + e.getStackTraceString());
                return new Map<String, Object>{
                    'isSuccess' => false,
                    'errorMessage' => errorMsg
                };
            }
        } catch (Exception e) {
            String errorMsg = 'Unexpected error in createExpenseLineItems: ' + e.getMessage();
            System.debug('Error: ' + errorMsg);
            System.debug('Exception stack trace: ' + e.getStackTraceString());
            return new Map<String, Object>{
                'isSuccess' => false,
                'errorMessage' => errorMsg
            };
        } finally {
            System.debug('=== End createExpenseLineItems ===');
        }
    }
    
    private static Map<String, Object> callGeminiAPI(String base64Data, String fileExtension) {
        try {
            System.debug('Starting callGeminiAPI method');
            HttpRequest req = new HttpRequest();
            String endpoint = GeminiConfig.getModelEndpoint();
            System.debug('Gemini API Endpoint: ' + endpoint);
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            
            Map<String, String> headers = GeminiConfig.getAuthHeaders();
            System.debug('Request Headers: ' + JSON.serialize(headers));
            for (String key : headers.keySet()) {
                req.setHeader(key, headers.get(key));
            }
            
            // Create the prompt for Gemini
            String prompt = 'Please analyze this receipt and extract the following information in JSON format: ' +
                          '{"vendorName": "name of the vendor", ' +
                          '"price": "total amount", ' +
                          '"expenseDate": "date of purchase in YYYY-MM-DD format", ' +
                          '"expenseDetail": "brief description of items purchased"}. ' +
                          'Only return the JSON object, no additional text or markdown formatting.';
            
            // Prepare the request body with both text and image
            Map<String, Object> requestBody = new Map<String, Object>{
                'contents' => new List<Map<String, Object>>{
                    new Map<String, Object>{
                        'parts' => new List<Map<String, Object>>{
                            new Map<String, Object>{
                                'text' => prompt
                            },
                            new Map<String, Object>{
                                'inline_data' => new Map<String, String>{
                                    'mime_type' => 'image/' + fileExtension.toLowerCase(),
                                    'data' => base64Data
                                }
                            }
                        }
                    }
                }
            };
            
            String requestBodyJson = JSON.serialize(requestBody);
            System.debug('Request Body (first 1000 chars): ' + requestBodyJson.substring(0, Math.min(1000, requestBodyJson.length())));
            req.setBody(requestBodyJson);
            
            System.debug('Sending HTTP request to Gemini API');
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            System.debug('Response Status Code: ' + res.getStatusCode());
            System.debug('Response Status: ' + res.getStatus());
            System.debug('Response Body (first 1000 chars): ' + res.getBody().substring(0, Math.min(1000, res.getBody().length())));
            
            if (res.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
                System.debug('Response Map: ' + JSON.serialize(responseMap));
                
                if (responseMap.containsKey('candidates')) {
                    List<Object> candidates = (List<Object>)responseMap.get('candidates');
                    if (!candidates.isEmpty()) {
                        Map<String, Object> candidate = (Map<String, Object>)candidates[0];
                        Map<String, Object> content = (Map<String, Object>)candidate.get('content');
                        List<Object> parts = (List<Object>)content.get('parts');
                        if (!parts.isEmpty()) {
                            Map<String, Object> part = (Map<String, Object>)parts[0];
                            String jsonResponse = (String)part.get('text');
                            
                            // Clean up the response by removing any markdown formatting or unwanted characters
                            jsonResponse = jsonResponse.replaceAll('```json', '')
                                                    .replaceAll('```', '')
                                                    .trim();
                            
                            System.debug('Cleaned JSON response: ' + jsonResponse);
                            try {
                                return (Map<String, Object>)JSON.deserializeUntyped(jsonResponse);
                            } catch(Exception e) {
                                System.debug('Error parsing JSON response: ' + e.getMessage());
                                System.debug('Raw response: ' + jsonResponse);
                                throw new AuraHandledException('Failed to parse expense details: ' + e.getMessage());
                            }
                        }
                    }
                }
            }
            
            throw new AuraHandledException('Failed to extract expense details. Status: ' + res.getStatus() + ', Body: ' + res.getBody());
        } catch (Exception e) {
            System.debug('Error in callGeminiAPI: ' + e.getMessage() + '\n' + e.getStackTraceString());
            throw new AuraHandledException('Error calling Gemini API: ' + e.getMessage());
        }
    }
    
    private static void createExpenseLineItem(Map<String, Object> extractedData, String expenseReportId) {
        System.debug('Creating expense line item with data: ' + JSON.serialize(extractedData));
        
        // Validate required fields
        if (!extractedData.containsKey('vendorName') || 
            !extractedData.containsKey('price') || 
            !extractedData.containsKey('expenseDate') || 
            !extractedData.containsKey('expenseDetail')) {
            throw new AuraHandledException('Missing required fields in extracted data');
        }
        
        try {
            Expense_Line_Item__c lineItem = new Expense_Line_Item__c(
                Expense_Report__c = expenseReportId,
                Vendor_Name__c = (String)extractedData.get('vendorName'),
                Price__c = Decimal.valueOf((String)extractedData.get('price')),
                Date_of_Expense__c = Date.valueOf((String)extractedData.get('expenseDate')),
                Expense_Detail__c = (String)extractedData.get('expenseDetail')
            );
            
            insert lineItem;
            System.debug('Successfully inserted line item: ' + lineItem.Id);
        } catch (Exception e) {
            System.debug('Error creating line item: ' + e.getMessage());
            throw new AuraHandledException('Failed to create expense line item: ' + e.getMessage());
        }
    }
} 