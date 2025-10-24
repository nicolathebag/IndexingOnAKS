from typing import List, Dict

class SearchIndexer:
    def __init__(self, index_name: str):
        self.index_name = index_name

    def index_document(self, document: Dict) -> None:
        """
        Index a single document.
        """
        # Logic to index the document
        print(f"Indexing document: {document} in index: {self.index_name}")

    def bulk_index_documents(self, documents: List[Dict]) -> None:
        """
        Index multiple documents in bulk.
        """
        for document in documents:
            self.index_document(document)

    def search(self, query: str) -> List[Dict]:
        """
        Search for documents in the index.
        """
        # Logic to perform search
        print(f"Searching for query: {query} in index: {self.index_name}")
        return []  # Return search results as a list of documents

    def delete_document(self, document_id: str) -> None:
        """
        Delete a document from the index by its ID.
        """
        # Logic to delete the document
        print(f"Deleting document with ID: {document_id} from index: {self.index_name}")