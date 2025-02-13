import os
import torch
from torch.utils.data import Dataset, DataLoader
from torchvision import transforms
from PIL import Image
import pandas as pd
import torch.nn.functional as F
import numpy as np
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader
import numpy as np
from collections import deque
import torch.nn as nn
from torchvision.utils import make_grid
import matplotlib.pyplot as plt
#from torch.optim.lr_scheduler import CosineAnnealingLR
from torch.optim.lr_scheduler import SequentialLR, LambdaLR, CosineAnnealingLR
from torch.optim.lr_scheduler import CosineAnnealingWarmRestarts

class StackedFramesDataset(Dataset):
    def __init__(self, root_dir, transform=None, frames_per_stack=20):
        self.root_dir = root_dir
        self.transform = transform
        self.frames_per_stack = frames_per_stack
        self.data = []  # Store paths to image sequences and labels

        # Load image sequences and corresponding labels
        self._load_sequences()

    def _load_sequences(self):
        # Traverse the directory structure to find image folders and labels.txt
        for subject in os.listdir(self.root_dir):
            subject_path = os.path.join(self.root_dir, subject)
            print("Building data for: ", subject_path)
            if os.path.isdir(subject_path):
                for sequence in os.listdir(subject_path):
                    sequence_path = os.path.join(subject_path, sequence)
                    if os.path.isdir(sequence_path):
                        # Load images
                        frames = sorted(
                            [os.path.join(sequence_path, f) for f in os.listdir(sequence_path) if f.endswith(('.png', '.jpg'))]
                        )
                        # Load labels
                        label_path = os.path.join(sequence_path, "labels.csv")
                        if os.path.exists(label_path):
                            labels = pd.read_csv(label_path, sep=",")  # Load 2D labels
                            labels = labels.apply(pd.to_numeric, errors='coerce')
                            labels = labels.fillna(0)
                            labels = labels.to_numpy()
                            if len(frames) == len(labels):  # Frames and labels must match exactly
                                self.data.append((frames, labels))
                            else:
                                print(f"Mismatch in frames ({len(frames)}) and labels ({len(labels)}) in {sequence_path}.")

    def __len__(self):
        return sum(len(frames) - self.frames_per_stack for frames, _ in self.data)

    def __getitem__(self, idx):
        # Find the sequence and corresponding stack based on index
        for frames, labels in self.data:
            num_stacks = len(frames) - self.frames_per_stack
            if idx < num_stacks:
                # Get the image paths and labels for the current stack
                stack_frames = frames[idx:idx + self.frames_per_stack]
                stack_labels = labels[idx:idx + self.frames_per_stack]

                # Load and preprocess images
                images = []
                for frame_path in stack_frames:
                    image = Image.open(frame_path).convert("L")  # Convert to grayscale
                    if self.transform:
                        image = self.transform(image)
                    images.append(torch.from_numpy(np.array(image, dtype=np.float32) / 255.0).unsqueeze(0))  # Add channel dim

                # Stack images into a 5D tensor: (frames_per_stack, 1, H, W)
                images_stack = torch.stack(images, dim=0)

                # Convert stack labels to a tensor and compute the median motion
                stack_labels_tensor = torch.tensor(stack_labels, dtype=torch.float32)
                median_labels = torch.median(stack_labels_tensor, dim=0).values  # Median along the temporal dimension

                # Return image stack and median motion vector
                return images_stack, median_labels
            else:
                idx -= num_stacks

        raise IndexError("Index out of range.")

    
def add_noise(img):
    return img + torch.randn_like(img) * 0.5

class EnergyBasedResNet3D(nn.Module):
    def __init__(self, base_model, feature_dim=1024, num_outputs=6):
        super(EnergyBasedResNet3D, self).__init__()
        self.base_model = base_model  # Pre-trained ResNet3D

        # Dynamically set combined input size
        self.combined_dim = feature_dim + num_outputs
        self.energy_head = nn.Sequential(
            nn.Linear(self.combined_dim, 512),
            nn.ReLU(),
            nn.Linear(512, 1)
        )

    def forward(self, x, y):
        # Extract features from base model
        features = self.base_model(x)  # Expected: [batch_size, frames, feature_dim]
        print(f"Features shape: {features.shape}")  # Debug features shape

        # Ensure temporal alignment
        if len(features.shape) == 2:
            features = features.unsqueeze(1)  # Add temporal dimension
        if len(y.shape) == 2:
            y = y.unsqueeze(1)  # Add temporal dimension

        # Concatenate features and labels
        combined = torch.cat([features, y], dim=-1)  # Combine along feature dimension
        print(f"Combined shape: {combined.shape}")  # Debug combined shape

        # Compute energy
        energy = self.energy_head(combined)  # Energy per frame
        print(f"Energy shape: {energy.shape}")  # Debug energy shape

        return energy, features



class ResNet3D(nn.Module):
    def __init__(self, num_classes=9, num_frames=20, kernel_size=(5, 3, 3), dropout_prob=0.05):
        super(ResNet3D, self).__init__()

        # Define padding to retain the spatial and temporal dimensions
        temporal_padding = (kernel_size[0] // 2, kernel_size[1] // 2, kernel_size[2] // 2)  # Centered padding

        self.num_frames = num_frames

        # Define the layers with the new kernel size
        self.layer1 = nn.Sequential(
            nn.Conv3d(in_channels=1, out_channels=64, kernel_size=kernel_size, stride=1,
                      padding=temporal_padding),
            nn.BatchNorm3d(64),
            nn.LeakyReLU(negative_slope=0.1, inplace=False),
            nn.Dropout(dropout_prob)
        )

        self.layer2 = nn.Sequential(
            nn.Conv3d(64, 128, kernel_size=kernel_size, stride=1,
                      padding=temporal_padding),
            nn.BatchNorm3d(128),
            nn.LeakyReLU(negative_slope=0.1, inplace=False),
            nn.Dropout(dropout_prob)
        )

        self.layer3 = nn.Sequential(
            nn.Conv3d(128, 256, kernel_size=kernel_size, stride=(1, 2, 2),  # Spatial downsampling
                      padding=temporal_padding),
            nn.BatchNorm3d(256),
            nn.LeakyReLU(negative_slope=0.1, inplace=False),
            nn.Dropout(dropout_prob)
        )

        self.layer4 = nn.Sequential(
            nn.Conv3d(256, 512, kernel_size=kernel_size, stride=(1, 2, 2),  # Spatial downsampling
                      padding=temporal_padding),
            nn.BatchNorm3d(512),
            nn.LeakyReLU(negative_slope=0.1, inplace=False),
            nn.Dropout(dropout_prob)
        )

        self.layer5 = nn.Sequential(
            nn.Conv3d(512, 1024, kernel_size=kernel_size, stride=(1, 2, 2),  # Spatial downsampling
                      padding=temporal_padding),
            nn.BatchNorm3d(1024),
            nn.LeakyReLU(negative_slope=0.1, inplace=False),
            nn.Dropout(dropout_prob)
        )

        #self.layer6 = nn.Sequential(
        #    nn.Conv3d(1024, 1024, kernel_size=kernel_size, stride=(1, 2, 2),  # Spatial downsampling
        #              padding=temporal_padding),
        #    nn.LeakyReLU(negative_slope=0.01, inplace=False),
        #    nn.Dropout(dropout_prob)
        #)

        # Global pooling with temporal preservation
        self.layer7 = nn.AdaptiveAvgPool3d((1, 1, 1))  # Temporal dimension preserved, spatial reduced

        # Fully connected layer for output
        self.fc = nn.Linear(1024, num_classes)  # Adjust for the reduced depth

    def forward(self, x):
        # Pass input through the layers
        x = self.layer1(x)
        x = self.layer2(x)
        x = self.layer3(x)
        x = self.layer4(x)
        x = self.layer5(x)
        #x = self.layer6(x)
        x = self.layer7(x)  # Output shape: [batch_size, channels, frames, 1, 1]

        # Flatten spatial dimensions, keep temporal
        x = x.view(x.size(0), -1)  # Shape: [batch_size, channels]

        # Frame-wise predictions
        predictions = self.fc(x)  # [batch_size, frames, motion_params]

        return predictions


import torch.nn.init as init
# Adjust weight initialization
def initialize_weights(m):
    if isinstance(m, nn.Conv3d) or isinstance(m, nn.Linear):
        nn.init.kaiming_normal_(m.weight, mode='fan_out', nonlinearity='relu')
        if m.bias is not None:
            nn.init.constant_(m.bias, 1e-4)

# Define L1 regularization function
def l1_regularization(model, lambda_l1):
    l1_loss = 0.0
    for param in model.parameters():
        if param.requires_grad:  # Only apply to trainable parameters
            l1_loss += torch.sum(torch.abs(param))
    return lambda_l1 * l1_loss

def entropy_loss(predictions, alpha=0.25):
    variance = torch.var(predictions, dim=0)  # Variance over the batch dimension

    # Step 2: Compute the mean variance across all parameters
    mean_variance = torch.mean(variance)
    if mean_variance < 1e-6:
        mean_variance = -30

    elif mean_variance > 20:
        mean_variance = 30

    loss = mean_variance * alpha
    return loss

def correlation_loss(predictions, ground_truth, weight=1.0):
    """
    Compute correlation-based loss while penalizing negative correlation.

    Args:
        predictions (torch.Tensor): Model predictions [batch_size, frames, features].
        ground_truth (torch.Tensor): Ground truth labels [batch_size, frames, features].
        weight (float): Weight to scale the correlation loss.

    Returns:
        torch.Tensor: Correlation loss value.
    """
    #predictions = predictions[:, :ground_truth.shape[1], :]
    # Mean center the predictions and ground truth
    pred_mean = torch.mean(predictions, dim=1, keepdim=True)
    gt_mean = torch.mean(ground_truth, dim=1, keepdim=True)
    
    pred_centered = predictions - pred_mean
    gt_centered = ground_truth - gt_mean
    
    # Compute covariance
    covariance = torch.mean(pred_centered * gt_centered, dim=1)
    
    # Compute standard deviations
    pred_std = torch.sqrt(torch.mean(pred_centered ** 2, dim=1) + 1e-8)
    gt_std = torch.sqrt(torch.mean(gt_centered ** 2, dim=1) + 1e-8)
    
    # Compute correlation coefficient
    correlation = covariance / (pred_std * gt_std)
    
    # Correlation loss (1 - r penalizes negative correlation)
    corr_loss = torch.mean(1 - correlation**2)  # Averaged across the batch
    
    return torch.mean(correlation**2), weight * corr_loss

def log_correlation_per_parameter(writer, epoch, predictions, ground_truth, tag="correlation"):
    """
    Log the Pearson correlation coefficient for each motion parameter separately.
    
    Args:
        writer: TensorBoard SummaryWriter.
        epoch: Current training epoch.
        predictions: Predicted values [batch_size, frames, motion_params].
        ground_truth: Ground truth values [batch_size, frames, motion_params].
        tag: Tag for the TensorBoard graph.
    """
    #predictions = predictions[:, :ground_truth.shape[1], :]  # Match frames
    num_params = predictions.shape[-1]
    for param_idx in range(num_params):
        pred_param = predictions[..., param_idx]
        gt_param = ground_truth[..., param_idx]

        # Compute correlation for the current parameter
        pred_mean = torch.mean(pred_param, dim=0, keepdim=True)
        gt_mean = torch.mean(gt_param, dim=0, keepdim=True)
        #print("preds: ", pred_param)
        #print("preds mean: ", pred_mean)
        pred_centered = pred_param - pred_mean
        gt_centered = gt_param - gt_mean

        #print("gts: ", gt_param)
        #print("gts mean: ", gt_mean)

        covariance = torch.mean(pred_centered * gt_centered, dim=0)
        pred_std = torch.sqrt(torch.mean(pred_centered ** 2, dim=0) + 1e-8)
        gt_std = torch.sqrt(torch.mean(gt_centered ** 2, dim=0) + 1e-8)

        correlation = torch.mean(covariance / (pred_std * gt_std))

        #print ("Correlation: ", correlation, " Covariance: ", covariance)

        # Log correlation for this parameter
        writer.add_scalar(f"{tag}/param_{param_idx}", correlation.item(), epoch)


def generate_negative_samples(y_true, noise_std=0.5):
    """
    Generate negative samples by adding Gaussian noise.

    Args:
        y_true (torch.Tensor): Ground truth labels [batch_size, features].
        noise_std (float): Standard deviation of noise.

    Returns:
        torch.Tensor: Negative samples [batch_size, features].
    """
    noise = torch.randn_like(y_true) * noise_std
    return y_true + noise

def energy_loss(model, inputs, y_true, y_false, lambda_l1=1e-4, lambda_mse=0.05):
    # Compute energies and predictions
    y_true_scaled = torch.sign(y_true) * torch.log1p(torch.abs(y_true))
    y_false_scaled = torch.sign(y_false) * torch.log1p(torch.abs(y_false))
    energy_true, predictions = model(inputs, y_true)
    energy_false, _ = model(inputs, y_false)

    # Contrastive energy loss (per frame)
    contrastive_loss = torch.mean(energy_true - energy_false)*2

    # Add optional L1 regularization
    l1_loss = l1_regularization(model, lambda_l1)

    mse_loss = torch.nn.functional.mse_loss(predictions[:,:-1,:], y_true)

    # Return combined loss and predictions
    return contrastive_loss + l1_loss + mse_loss*lambda_mse, predictions

def log_mse_per_parameter(writer, epoch, predictions, ground_truth, tag="mse"):
    """
    Log the Mean Squared Error (MSE) for each motion parameter separately.
    
    Args:
        writer: TensorBoard SummaryWriter.
        epoch: Current training epoch.
        predictions: Predicted values [batch_size, frames, motion_params].
        ground_truth: Ground truth values [batch_size, frames, motion_params].
        tag: Tag for the TensorBoard graph.
    """
    #predictions = predictions[:, :ground_truth.shape[1], :]  # Match frames
    num_params = predictions.shape[-1]
    for param_idx in range(num_params):
        pred_param = predictions[..., param_idx]
        gt_param = ground_truth[..., param_idx]

        # Compute MSE for the current parameter
        mse = torch.nn.functional.mse_loss(pred_param, gt_param)

        # Log MSE for this parameter
        writer.add_scalar(f"{tag}/param_{param_idx}", mse.item(), epoch)


def visualize_predicted_vs_actual(pred_translation, translation_labels, pred_rotation, rotation_labels, writer, global_step, label_="train"):
    """
    Visualize predicted vs actual values for translation and rotation with line fit and R^2 score.

    Parameters:
    - pred_translation: Predicted translation values (batch_size, seq_len, 3).
    - translation_labels: Ground truth translation values (batch_size, seq_len, 3).
    - pred_rotation: Predicted rotation values (batch_size, seq_len, 3).
    - rotation_labels: Ground truth rotation values (batch_size, seq_len, 3).
    - writer: TensorBoard SummaryWriter instance.
    - global_step: Global step for TensorBoard logging.
    """
    from sklearn.metrics import r2_score
    from sklearn.linear_model import LinearRegression
    def plot_with_fit(ax, y_pred, y_true, title, xlabel, ylabel):
        # Flatten data
        y_pred_flat = y_pred.flatten()
        y_true_flat = y_true.flatten()

        # Line fit using linear regression
        print (y_pred_flat.shape, y_true_flat.shape)
        reg = LinearRegression().fit(y_true_flat.reshape(-1, 1), y_pred_flat)
        #slope, intercept, r_value, p_value, std_err = scipy.stats.linregress(y_true_flat.reshape(-1, 1), y_pred_flat)
        r2 = r2_score(y_true_flat, y_pred_flat)
        line_x = np.linspace(y_true_flat.min(), y_true_flat.max(), 100)
        line_y = reg.predict(line_x.reshape(-1, 1))

        # Plot scatter and line
        ax.scatter(y_true_flat, y_pred_flat, alpha=0.5, label="Data")
        ax.plot(line_x, line_y, color='red', label=f"Line Fit (R²={r2:.2f})")
        ax.set_title(title)
        ax.set_xlabel(xlabel)
        ax.set_ylabel(ylabel)
        ax.legend()

    # Convert tensors to NumPy arrays
    pred_translation = pred_translation#.squeeze(0)#.cpu().detach().numpy()
    translation_labels = translation_labels#.cpu().detach().numpy()
    pred_rotation = pred_rotation#.squeeze(0)#.cpu().detach().numpy()
    rotation_labels = rotation_labels#.cpu().detach().numpy()
    pred_translation = torch.tensor(pred_translation, device="cuda" if torch.cuda.is_available() else "cpu")
    pred_rotation = torch.tensor(pred_rotation, device="cuda" if torch.cuda.is_available() else "cpu")
    pred_translation = torch.where(torch.isnan(pred_translation), torch.tensor(0.0, device=pred_translation.device), pred_translation)
    pred_translation = torch.where(torch.isinf(pred_translation), torch.tensor(0.0, device=pred_translation.device), pred_translation)
    pred_rotation = torch.where(torch.isnan(pred_rotation), torch.tensor(0.0, device=pred_rotation.device), pred_rotation)
    pred_rotation = torch.where(torch.isinf(pred_rotation), torch.tensor(0.0, device=pred_rotation.device), pred_rotation)    
    pred_rotation = pred_rotation.cpu().detach().numpy()
    pred_translation = pred_translation.cpu().detach().numpy()
    fig, axes = plt.subplots(2, 3, figsize=(18, 10))
    print (pred_rotation.shape, rotation_labels.shape)
    print (pred_translation.shape, translation_labels.shape)
    # Plot translation components
    for i, label in enumerate(["X", "Y", "Z"]):
        plot_with_fit(
            axes[0, i], pred_translation[..., i], translation_labels[..., i],
            title=f"Translation {label}: Predicted vs Actual",
            xlabel="Actual",
            ylabel="Predicted"
        )

    # Plot rotation components
    for i, label in enumerate(["Roll", "Pitch", "Yaw"]):
        plot_with_fit(
            axes[1, i], pred_rotation[..., i], rotation_labels[..., i],
            title=f"Rotation {label}: Predicted vs Actual",
            xlabel="Actual",
            ylabel="Predicted"
        )

    plt.tight_layout()

    # Save to TensorBoard
    writer.add_figure(label_+"Predicted vs Actual (with Fit)", fig, global_step)
    plt.close(fig)

def log_mse(writer, epoch, predictions, ground_truth, tag="mse"):
    """
    Log the Mean Squared Error (MSE) between predictions and ground truth.
    
    Args:
        writer: TensorBoard SummaryWriter.
        epoch: Current training epoch.
        predictions: Predicted values [batch_size, frames, motion_params].
        ground_truth: Ground truth values [batch_size, frames, motion_params].
        tag: Tag for the TensorBoard graph.
    """
    mse = torch.nn.functional.mse_loss(predictions, ground_truth)
    writer.add_scalar(tag, mse.item(), epoch)

def variability_loss(predictions, alpha=0.25):
    variance = torch.var(predictions, dim=0)  # Variance over the batch dimension

    # Step 2: Compute the mean variance across all parameters
    mean_variance = torch.mean(variance) * alpha
    if mean_variance < 1e-6:
        mean_variance = -torch.tensor(20, dtype=torch.float32, device="cuda", requires_grad=True)

    elif mean_variance > 20:
        mean_variance = torch.tensor(20, dtype=torch.float32, device="cuda", requires_grad=True)

    loss = mean_variance 
    return loss

def zero_penalty_loss(pred, weight=0.05):
    penalty = weight * torch.mean(torch.exp(-torch.abs(pred)))
    return penalty

if __name__ == '__main__':
    from torch.amp import GradScaler
    from torch.utils.tensorboard import SummaryWriter
    from sklearn.model_selection import train_test_split
    from torch.utils.data import DataLoader, Subset

    #torch.manual_seed(1324)
    train_transforms = transforms.Compose([
        #transforms.RandomHorizontalFlip(p=0.5),
        #transforms.Resize((96, 96)),
        transforms.RandomRotation(degrees=10),
        transforms.GaussianBlur(kernel_size=(15, 15), sigma=(0.5, 2.5)),
        transforms.ToTensor(),
        transforms.Lambda(add_noise) 
    ])
    # Initialize the GradScaler
    #scaler = GradScaler(init_scale=8.0, device='cuda')
    scaler = GradScaler(enabled=False)
    dataset = StackedFramesDataset(root_dir='TrainingData2/', frames_per_stack=20, transform = train_transforms)
    print ("Splitting data into train and validation.")
    indices = list(range(len(dataset)))
    train_indices, val_indices = train_test_split(indices, test_size=0.1, random_state=5205)
    num_workers = 12
    num_outputs = 6
    print ("Number of workers: ", num_workers)
    # Create subset datasets
    train_dataset = Subset(dataset, train_indices)
    val_dataset = Subset(dataset, val_indices)
    batch_size = 4
    data_loader = DataLoader(
        train_dataset,
        batch_size=batch_size,
        shuffle=True,
        num_workers=num_workers,
        pin_memory=True,
        persistent_workers=True,
        prefetch_factor=8  # Default is 2, increasing can help
    )
    val_loader = DataLoader(val_dataset, batch_size=batch_size, shuffle=True)
    print("Total number of batches:", len(data_loader))
    print("Total number of samples:", len(data_loader.dataset))
    # Set up the model, loss, and optimizer
    device = torch.device("cuda:0" if torch.cuda.is_available() else "cpu")
    #model = ResNet3D(num_classes=num_outputs, dropout_prob=0.25).to(device)
    #model.apply(initialize_weights)
    # Initialize the energy-based model
    energy_model = ResNet3D(num_classes=num_outputs, dropout_prob=0.5).to(device)
    #energy_model = EnergyBasedResNet3D(base_model, feature_dim=1024, num_outputs=num_outputs).to(device)
    energy_model.apply(initialize_weights)
    # Optimizer and scheduler
    optimizer = torch.optim.SGD(energy_model.parameters(), momentum=0.9, lr=1e-4, weight_decay=1e-4)
    #scheduler = torch.optim.lr_scheduler.ReduceLROnPlateau(optimizer, mode='min', patience=2, factor=0.5)
    #scheduler = optim.lr_scheduler.StepLR(optimizer, step_size=5, gamma=0.9)
    num_epochs = 50
    scheduler = torch.optim.lr_scheduler.OneCycleLR(
        optimizer,
        max_lr=1e-3,  # Peak LR
        steps_per_epoch=len(data_loader),
        epochs=num_epochs,
        pct_start=0.1,  # 10% of training for warmup
    )
    
    writer = SummaryWriter('runs/experiment6')
    criterion = nn.MSELoss(reduction='mean')#nn.HuberLoss(delta=1.0, reduction='mean')
    # Training loop
    
    log_interval = 25
    for epoch in range(num_epochs):
        energy_model.train()
        total_loss = 0.0
        predictionsList = []
        labs = []
        for batch_idx, (inputs, labels) in enumerate(data_loader):
            
            images_stack = inputs.squeeze(2)#torch.stack(images_stack, dim=0)  # Shape: [frames_per_stack, 1, H, W]
            labels = labels + torch.randn_like(labels) * 0.02
            labels = labels[:,[1,2,3,4,8,9]] * 100
            inputs, labels = images_stack.to(device), labels.to(device)
            labels = torch.sign(labels) * torch.log1p(torch.abs(labels)) 
            
            # Generate negative samples
            #negative_labels = generate_negative_samples(labels)

            inputs = inputs.permute(0, 2, 1, 3, 4)

            # Zero gradients
            optimizer.zero_grad()

            #print ("inputs shape: ", inputs.shape, " labels shape: ", labels.shape)

            # Compute energy-based loss
            with torch.cuda.amp.autocast():
                #loss, predictions = energy_loss(energy_model, inputs, labels, negative_labels)
                predictions = energy_model(inputs)
                loss = criterion(predictions, labels)*(10)
                r, corr_loss = correlation_loss(predictions, labels, weight=50.0)
                l1_loss = l1_regularization(energy_model, 1e-4)
                var_loss = variability_loss(predictions, alpha=10.0)
                loss = loss + corr_loss + l1_loss - var_loss
                zero_penaltyy = zero_penalty_loss(predictions, weight=50.0)
                loss = loss + zero_penaltyy
                loss = loss/10.0
                #print ("preds shape:", predictions.shape)
                #print ("Predictions: ", predictions.shape)
                loss.backward()
                torch.nn.utils.clip_grad_norm_(energy_model.parameters(), max_norm=1.0)

                #corr, corr_loss = correlation_loss(predictions, labels, weight=1.0)

                # Optimize
                optimizer.step()
                total_loss += loss.item()

                global_step = epoch * len(data_loader) + batch_idx
                if batch_idx % log_interval == 0:  # Only log every `log_interval` batches
                    
                    writer.add_scalar('Loss/train', loss.item(), epoch * len(data_loader) + batch_idx)
                    writer.add_scalar('Loss/Correlation Loss', corr_loss.item(), epoch * len(data_loader) + batch_idx)
                    writer.add_scalar('Loss/Variance Loss', var_loss.item(), epoch * len(data_loader) + batch_idx)
                    writer.add_scalar('Loss/Zero Loss', zero_penaltyy.item(), epoch * len(data_loader) + batch_idx)
                    writer.add_scalar('Correlation/overall', r.item(), epoch * len(data_loader) + batch_idx)
                   
                    #log_correlation_per_parameter(writer, epoch * len(data_loader) + batch_idx, predictions, labels, tag="correlation")
                    log_mse_per_parameter(writer, epoch * len(data_loader) + batch_idx, predictions, labels, tag="mse")

                    for name, param in energy_model.named_parameters():
                        if param.requires_grad:
                            # Log gradient norms
                            if param.grad is not None:
                                writer.add_scalar(f'Gradients/{name}', param.grad.norm().item(), epoch * len(data_loader) + batch_idx)
                            
                            # Log parameter histograms
                            writer.add_histogram(f'Weights/{name}', param, epoch)
                print(f"Epoch [{epoch + 1}/{num_epochs}], Batch [{batch_idx + 1}/{len(data_loader)}], Loss: {loss.item():.4f}")
                if batch_idx > len(data_loader)-100 and batch_idx < len(data_loader)-2:
                    predictions_unscaled = torch.sign(predictions) * (torch.exp(torch.abs(predictions)) - 1) /100
                    labels_unscaled = torch.sign(labels) * (torch.exp(torch.abs(labels)) - 1) / 100
                    predictionsList.append(predictions_unscaled.cpu().detach().numpy())
                    labs.append(labels_unscaled.cpu().detach().numpy())
                    #if batch_idx==4:
                    #    break
            scheduler.step()


        predictions_array = np.concatenate(predictionsList, axis=0)  # Shape: [total_samples, frames, 6]
        labels_array = np.concatenate(labs, axis=0)  # Shape: [total_samples, frames, 6]
        # Translation predictions and labels
        pred_translation = predictions_array[:, 0:3]  # Shape: [total_samples, frames, 3]
        translation_labels = labels_array[:, 0:3]

        # Rotation predictions and labels
        pred_rotation = predictions_array[:, 3:]  # Shape: [total_samples, frames, 3]
        rotation_labels = labels_array[:, 3:]
        visualize_predicted_vs_actual(pred_translation, translation_labels, pred_rotation, rotation_labels, writer, global_step, label_="Training")
        avg_loss = total_loss / len(data_loader)
        print(f"Epoch {epoch+1}/{num_epochs}, Loss: {avg_loss:.4f}")

        # Validation
        energy_model.eval()
        with torch.no_grad():
            val_loss = 0.0
            predictionsList = []
            labs = []
            for val_batch_idx, (inputs, labels) in enumerate(val_loader):
                labels = labels[:,[1,2,3,4,8,9]] * 100
                #labels = labels + torch.randn_like(labels) * 0.001
                inputs, labels = inputs.to(device), labels.to(device)
                labels = torch.sign(labels) * torch.log1p(torch.abs(labels)) 
                #negative_labels = generate_negative_samples(labels)
                inputs = inputs.squeeze(2)#torch.stack(images_stack, dim=0)  # Shape: [frames_per_stack, 1, H, W]
                inputs = inputs.permute(0, 2, 1, 3, 4)  # Should result in [batch_size, 1, frames_per_stack, H, W]
                with torch.cuda.amp.autocast():
                    predictions = energy_model(inputs)
                loss = criterion(predictions, labels)
                val_loss += loss.item()
                predictions_unscaled = torch.sign(predictions) * (torch.exp(torch.abs(predictions)) - 1) / 100
                labels_unscaled = torch.sign(labels) * (torch.exp(torch.abs(labels)) - 1) /100
                predictionsList.append(predictions_unscaled.cpu().detach().numpy())
                labs.append(labels_unscaled.cpu().detach().numpy())

                if val_batch_idx > 60:
                    break

            predictions_array = np.concatenate(predictionsList, axis=0)  # Shape: [total_samples, frames, 6]
            labels_array = np.concatenate(labs, axis=0)  # Shape: [total_samples, frames, 6]
            # Translation predictions and labels
            pred_translation = predictions_array[:, 0:3]  # Shape: [total_samples, frames, 3]
            translation_labels = labels_array[:, 0:3]

            # Rotation predictions and labels
            pred_rotation = predictions_array[:, 3:]  # Shape: [total_samples, frames, 3]
            rotation_labels = labels_array[:, 3:]
            visualize_predicted_vs_actual(pred_translation, translation_labels, pred_rotation, rotation_labels, writer, global_step, label_="Validation")
            avg_val_loss = val_loss / len(val_loader)
            print(f"Validation Loss: {avg_val_loss:.4f}")
            writer.add_scalar('Loss/Avg Validation', avg_val_loss, epoch * len(data_loader) + batch_idx)
        model_save_path = f'Resnet_models/model_epoch_{epoch + 1}.pth'
        torch.save(energy_model.state_dict(), model_save_path)
        