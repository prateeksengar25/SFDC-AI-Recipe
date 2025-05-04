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
            if (contentVersionId == null) {
                throw new AuraHandledException('Content Version ID is required');
            }
            
            // Get the content version
            ContentVersion cv = [SELECT Id, VersionData, Title, FileExtension 
                               FROM ContentVersion 
                               WHERE Id = :contentVersionId 
                               WITH SECURITY_ENFORCED];
            
            // Convert the file to base64
            String base64Data = EncodingUtil.base64Encode(cv.VersionData);
            
            // Create the prompt for Gemini
            String prompt = 'Please analyze this receipt and extract the following information in JSON format: ' +
                          '{"vendorName": "name of the vendor", ' +
                          '"price": "total amount", ' +
                          '"expenseDate": "date of purchase in YYYY-MM-DD format", ' +
                          '"expenseDetail": "brief description of items purchased"}. ' +
                          'Only return the JSON object, no additional text or markdown formatting.';
            
            // Prepare the request body
            Map<String, Object> requestBody = new Map<String, Object>{
                'contents' => new List<Map<String, Object>>{
                    new Map<String, Object>{
                        'parts' => new List<Map<String, Object>>{
                            new Map<String, Object>{
                                'text' => prompt
                            },
                            new Map<String, Object>{
                                'inline_data' => new Map<String, String>{
                                    'mime_type' => 'image/' + cv.FileExtension.toLowerCase(),
                                    'data' => base64Data
                                }
                            }
                        }
                    }
                }
            };
            
            // Call Gemini API
            Map<String, Object> apiResponse = GeminiService.callGeminiAPI(JSON.serialize(requestBody));
            Integer statusCode = (Integer)apiResponse.get('statusCode');
            
            if (statusCode != 200) {
                throw new AuraHandledException('Gemini API call failed. Status: ' + apiResponse.get('status') + ', Body: ' + apiResponse.get('body'));
            }
            
            // Parse the response
            String responseBody = (String)apiResponse.get('body');
            Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(responseBody);
            if (responseMap.containsKey('candidates')) {
                List<Object> candidates = (List<Object>)responseMap.get('candidates');
                if (!candidates.isEmpty()) {
                    Map<String, Object> candidate = (Map<String, Object>)candidates[0];
                    Map<String, Object> content = (Map<String, Object>)candidate.get('content');
                    List<Object> parts = (List<Object>)content.get('parts');
                    if (!parts.isEmpty()) {
                        Map<String, Object> part = (Map<String, Object>)parts[0];
                        String jsonResponse = (String)part.get('text');
                        
                        // Clean up the response
                        jsonResponse = jsonResponse.replaceAll('```json', '')
                                                .replaceAll('```', '')
                                                .trim();
                        
                        return (Map<String, Object>)JSON.deserializeUntyped(jsonResponse);
                    }
                }
            }
            
            throw new AuraHandledException('Invalid response format from Gemini API');
        } catch (Exception e) {
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
                // Query the original ContentVersion
                ContentVersion originalCv = [SELECT Id, Title, FileExtension, VersionData, PathOnClient, ContentDocumentId
                                          FROM ContentVersion 
                                          WHERE Id = :contentVersionId 
                                          WITH SECURITY_ENFORCED];
                
                // Create a new title based on vendor name and expense date
                String newTitle = (String)extractedData.get('vendorName') + ' - ' + 
                                ((String)extractedData.get('expenseDate')).replace('-', '') + 
                                (String.isNotBlank(originalCv.FileExtension) ? '.' + originalCv.FileExtension : '');
                
                // Create a new ContentVersion with the updated title
                ContentVersion newCv = new ContentVersion(
                    Title = newTitle,
                    PathOnClient = newTitle,
                    VersionData = originalCv.VersionData,
                    ContentDocumentId = originalCv.ContentDocumentId,
                    IsMajorVersion = false
                );
                
                insert newCv;
                System.debug('Successfully created new version with title: ' + newTitle);
            }
        } catch (Exception e) {
            System.debug('Error creating line item or renaming file: ' + e.getMessage());
            throw new AuraHandledException('Failed to create expense line item: ' + e.getMessage());
        }
    }
} 