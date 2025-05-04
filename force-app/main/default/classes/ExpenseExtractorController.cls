/**
 * Controller class for extracting expense details from uploaded documents using Gemini AI
 */
public with sharing class ExpenseExtractorController {
    /**
     * @description Extracts expense details from an uploaded document using Gemini AI
     * @param contentVersionId The ID of the ContentVersion record containing the document
     * @param expenseReportId The ID of the Expense Report to associate the extracted details with
     * @return Map<String, Object> containing the extracted expense details
     * @throws AuraHandledException if the extraction fails or required parameters are missing
     */
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

    /**
     * @description Creates expense line items based on extracted data
     * @param params Map containing expense report ID, content version ID, and extracted data
     * @return Map<String, Object> with success status and message or error details
     */
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
            String contentVersionId = (String)params.get('contentVersionId');
            System.debug('expenseReportId: ' + expenseReportId);
            System.debug('contentVersionId: ' + contentVersionId);
            
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
                createExpenseLineItem(extractedData, expenseReportId, contentVersionId);
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
    
    /**
     * @description Makes an API call to Gemini AI to extract expense details from document
     * @param base64Data Base64 encoded document data
     * @param fileExtension File extension of the uploaded document
     * @return Map<String, Object> containing the extracted expense details
     * @throws AuraHandledException if the API call fails or response parsing fails
     */
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
    
    /**
     * @description Creates a new expense line item record with the extracted data and renames the uploaded file
     * @param extractedData Map containing the extracted expense details
     * @param expenseReportId ID of the expense report to associate the line item with
     * @param contentVersionId ID of the uploaded file to rename
     * @throws AuraHandledException if required fields are missing or record creation fails
     */
    private static void createExpenseLineItem(Map<String, Object> extractedData, String expenseReportId, String contentVersionId) {
        System.debug('Creating expense line item with data: ' + JSON.serialize(extractedData));
        
        // Validate required fields
        if (!extractedData.containsKey('vendorName') || 
            !extractedData.containsKey('price') || 
            !extractedData.containsKey('expenseDate') || 
            !extractedData.containsKey('expenseDetail')) {
            throw new AuraHandledException('Missing required fields in extracted data');
        }
        
        try {
            // Create the expense line item
            Expense_Line_Item__c lineItem = new Expense_Line_Item__c(
                Expense_Report__c = expenseReportId,
                Vendor_Name__c = (String)extractedData.get('vendorName'),
                Price__c = Decimal.valueOf((String)extractedData.get('price')),
                Date_of_Expense__c = Date.valueOf((String)extractedData.get('expenseDate')),
                Expense_Detail__c = (String)extractedData.get('expenseDetail')
            );
            
            insert lineItem;
            System.debug('Successfully inserted line item: ' + lineItem.Id);

            // Rename the uploaded file
            if (String.isNotBlank(contentVersionId)) {
                ContentVersion cv = [SELECT Id, Title, FileExtension 
                                   FROM ContentVersion 
                                   WHERE Id = :contentVersionId 
                                   WITH SECURITY_ENFORCED];
                
                // Create a new title based on vendor name and expense date
                String newTitle = (String)extractedData.get('vendorName') + ' - ' + 
                                ((String)extractedData.get('expenseDate')).replace('-', '') + 
                                (String.isNotBlank(cv.FileExtension) ? '.' + cv.FileExtension : '');
                
                // Update the ContentVersion title
                cv.Title = newTitle;
                update cv;
                System.debug('Successfully renamed file to: ' + newTitle);
            }
        } catch (Exception e) {
            System.debug('Error creating line item or renaming file: ' + e.getMessage());
            throw new AuraHandledException('Failed to create expense line item: ' + e.getMessage());
        }
    }
} 