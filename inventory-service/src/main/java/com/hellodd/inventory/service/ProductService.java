package com.hellodd.inventory.service;

import com.hellodd.inventory.dto.StockUpdateRequest;
import com.hellodd.inventory.model.Product;
import com.hellodd.inventory.repository.ProductRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;

/**
 * Service for managing products and inventory operations.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class ProductService {

    private final ProductRepository productRepository;

    /**
     * Get all products
     */
    public List<Product> getAllProducts() {
        return productRepository.findByActiveTrue();
    }

    /**
     * Get a product by ID
     */
    public Optional<Product> getProductById(String id) {
        return productRepository.findById(id);
    }

    /**
     * Get a product by SKU
     */
    public Optional<Product> getProductBySku(String sku) {
        return productRepository.findBySku(sku);
    }

    /**
     * Get products that are in stock
     */
    public List<Product> getInStockProducts() {
        return productRepository.findInStockProducts();
    }

    /**
     * Get products with low stock
     */
    public List<Product> getLowStockProducts(Integer threshold) {
        return productRepository.findLowStockProducts(threshold);
    }

    /**
     * Update stock level for a product
     */
    @Transactional
    public Product updateStock(String productId, StockUpdateRequest request) {
        Product product = productRepository.findById(productId)
            .orElseThrow(() -> new IllegalArgumentException("Product not found: " + productId));

        Integer currentStock = product.getStockLevel();
        Integer newStock;

        switch (request.getOperation().toLowerCase()) {
            case "add":
                newStock = currentStock + request.getQuantity();
                break;
            case "subtract":
                newStock = Math.max(0, currentStock - request.getQuantity());
                break;
            case "set":
                newStock = Math.max(0, request.getQuantity());
                break;
            default:
                throw new IllegalArgumentException("Invalid operation: " + request.getOperation());
        }

        product.setStockLevel(newStock);

        log.info("Stock updated for product {}: {} -> {}",
            product.getSku(), currentStock, newStock);

        return productRepository.save(product);
    }

    /**
     * Reserve stock for an order (increases reserved stock)
     */
    @Transactional
    public Product reserveStock(String productId, Integer quantity) {
        Product product = productRepository.findById(productId)
            .orElseThrow(() -> new IllegalArgumentException("Product not found: " + productId));

        if (product.getAvailableStock() < quantity) {
            throw new IllegalStateException("Insufficient stock for product: " + product.getSku());
        }

        product.setReservedStock(product.getReservedStock() + quantity);

        log.info("Reserved {} units of product {}", quantity, product.getSku());

        return productRepository.save(product);
    }

    /**
     * Release reserved stock (decreases reserved stock)
     */
    @Transactional
    public Product releaseStock(String productId, Integer quantity) {
        Product product = productRepository.findById(productId)
            .orElseThrow(() -> new IllegalArgumentException("Product not found: " + productId));

        Integer newReserved = Math.max(0, product.getReservedStock() - quantity);
        product.setReservedStock(newReserved);

        log.info("Released {} units of product {}", quantity, product.getSku());

        return productRepository.save(product);
    }
}