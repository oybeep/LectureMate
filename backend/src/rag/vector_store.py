import chromadb
from chromadb.config import Settings
import os

class VectorDBManager:
    def __init__(self, db_path: str = "./chroma_db"):
        # 로컬 디스크에 데이터 보존
        self.client = chromadb.PersistentClient(path=db_path)
        
    def get_or_create_collection(self, collection_name: str = "lecture_notes"):
        """과목/프로젝트별 Collection 생성 및 로드"""
        return self.client.get_or_create_collection(
            name=collection_name,
            metadata={"hnsw:space": "cosine"}  # 코사인 유사도 기준 검색
        )

    def add_documents(self, collection_name: str, ids: list, documents: list, metadatas: list = None):
        """CREATE: 텍스트 및 메타데이터 저장"""
        collection = self.get_or_create_collection(collection_name)
        collection.add(
            ids=ids,
            documents=documents,
            metadatas=metadatas
        )

    def query_similar(self, collection_name: str, query_text: str, n_results: int = 2):
        """READ: 유사도 기반 검색"""
        collection = self.get_or_create_collection(collection_name)
        results = collection.query(
            query_texts=[query_text],
            n_results=n_results
        )
        return results

    def delete_document(self, collection_name: str, doc_id: str):
        """DELETE: 특정 문서 삭제"""
        collection = self.get_or_create_collection(collection_name)
        collection.delete(ids=[doc_id])